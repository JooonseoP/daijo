# 다잊어 MVP 핵심 루프 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 위치 기반 지오펜싱 쇼핑 리마인더의 핵심 루프(목록 CRUD → 매장 시드 → 가까운 20개 지오펜스 등록 → ENTER 알림 → 알림 탭 진입)를 Android용 MVP로 구현한다.

**Architecture:** feature-first 레이어링. 플랫폼 서비스(알림/지오펜스/위치)는 전부 인터페이스 뒤로 격리해 유닛 테스트에서 fake를 주입한다. 순수 로직(거리 계산, 시드 파싱, 페이로드 빌더, repository CRUD, 오케스트레이션)은 인메모리 Drift와 fake로 기기 없이 검증한다. 실제 지오펜스 트리거/네이티브 알림/GPS는 기기 수동 테스트로만 검증한다.

**Tech Stack:** Flutter 3.29.2 / Dart ^3.7.2, Riverpod, Drift(SQLite) + build_runner, flutter_local_notifications, native_geofence 1.3.x, geolocator, permission_handler.

**Spec:** `docs/superpowers/specs/2026-09-16-daijo-mvp-core-loop-design.md`

## Global Constraints

- 타겟 플랫폼: **Android 우선** (iOS 코드는 컴파일만 되게 유지, 실동작 비대상).
- 매장 좌표: `assets/data/stores_seed.json` 번들 → 첫 실행 시에만 DB 적재(멱등).
- 가까운 매장 **N = 20**, 앱 실행 시마다 현재 위치 기준 재선별 후 지오펜스 **전량 재등록**.
- 지오펜스 **반경 = 150m**, 트리거 = `GeofenceEvent.enter`.
- 상태관리 = **Riverpod**, 로컬 DB = **Drift**(테스트는 in-memory), 알림 = **flutter_local_notifications**, 지오펜스 = **native_geofence**.
- 쇼핑 목록이 **비어 있으면 알림하지 않는다**.
- 권한 거부 시에도 앱은 **순수 목록 앱으로 계속 동작**하고, 지오펜싱 비활성 상태를 배너로 표시.
- 모든 플랫폼 서비스는 인터페이스 뒤에 격리(테스트 mock 주입 가능).
- 생성 코드(`*.g.dart`)는 커밋에 포함한다. 각 태스크는 `flutter analyze` 무경고를 유지한다.

---

## File Structure

```
lib/
  main.dart                                 앱 진입: ProviderScope + 부트스트랩
  app.dart                                  MaterialApp, 라우팅, 알림 탭 핸들링
  bootstrap.dart                            초기화 시퀀스(DB/시드/알림/권한/지오펜스)
  core/
    db/app_database.dart                    Drift DB + 테이블(ShoppingItems, Stores)
    db/app_database.g.dart                  (생성)
    location/location_service.dart          LocationService 인터페이스 + 결과 타입
    location/geolocator_location_service.dart  concrete(geolocator/permission_handler)
    notifications/notification_service.dart 인터페이스 + NotificationPayload
    notifications/notification_payload_builder.dart  순수 페이로드 빌더
    notifications/flutter_local_notification_service.dart concrete
    geofence/geofence_service.dart          인터페이스 + GeofenceRegion 값 타입
    geofence/native_geofence_service.dart   concrete(native_geofence) + 백그라운드 콜백
  features/
    shopping_list/
      domain/shopping_item.dart             모델(Drift 행 매핑 편의 포함)
      data/shopping_item_repository.dart     DAO/repository(CRUD + watch)
      presentation/shopping_list_screen.dart UI
      presentation/shopping_list_controller.dart Riverpod AsyncNotifier
    stores/
      domain/store.dart                     Store 모델
      data/store_seed_loader.dart           시드 JSON 파싱 + 멱등 적재
      data/store_repository.dart            stores 조회
      application/geo_math.dart             Haversine 거리 + 가까운 N 선별(순수)
      application/geofence_manager.dart      오케스트레이션(위치→선별→재등록)
  providers.dart                            Riverpod provider 정의 모음
assets/
  data/stores_seed.json                     테스트용 매장 5~10개
test/
  core/db/app_database_test.dart
  features/shopping_list/shopping_item_repository_test.dart
  features/stores/store_seed_loader_test.dart
  features/stores/geo_math_test.dart
  core/notifications/notification_payload_builder_test.dart
  features/stores/geofence_manager_test.dart
  features/shopping_list/shopping_list_controller_test.dart
  features/shopping_list/shopping_list_screen_test.dart
  support/fakes.dart                        fake 서비스 모음
```

---

### Task 1: 프로젝트 셋업 & 의존성

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/data/stores_seed.json`
- Delete: `test/widget_test.dart` (템플릿 기본 테스트, 이후 태스크에서 실제 테스트로 대체)

**Interfaces:**
- Consumes: 없음
- Produces: 프로젝트에 설치된 패키지들(`drift`, `riverpod`/`flutter_riverpod`, `native_geofence`, `geolocator`, `permission_handler`, `flutter_local_notifications`, `path_provider`, `sqlite3_flutter_libs`; dev: `drift_dev`, `build_runner`, `flutter_test`), `assets/data/stores_seed.json` 에셋 경로.

- [ ] **Step 1: 런타임 의존성 추가**

`flutter pub add` 로 호환 버전을 자동 해석시킨다(수동 버전 핀 금지):

```bash
cd E:/Joonseo/dev_works/daijo
flutter pub add flutter_riverpod drift sqlite3_flutter_libs path_provider \
  flutter_local_notifications native_geofence geolocator permission_handler
flutter pub add dev:drift_dev dev:build_runner
```

- [ ] **Step 2: 에셋 등록**

`pubspec.yaml` 의 `flutter:` 섹션 `uses-material-design: true` 아래에 추가:

```yaml
  assets:
    - assets/data/stores_seed.json
```

- [ ] **Step 3: 시드 JSON 작성 (테스트용 소수 매장)**

`assets/data/stores_seed.json` — 좌표는 서울 도심 실좌표 근사값(테스트용):

```json
{
  "version": 1,
  "stores": [
    { "id": "daiso-myeongdong",   "name": "다이소 명동역점",   "latitude": 37.560986, "longitude": 126.986072 },
    { "id": "daiso-gangnam",      "name": "다이소 강남역점",   "latitude": 37.497942, "longitude": 127.027621 },
    { "id": "daiso-hongdae",      "name": "다이소 홍대입구역점", "latitude": 37.556825, "longitude": 126.923607 },
    { "id": "daiso-jamsil",       "name": "다이소 잠실점",     "latitude": 37.513272, "longitude": 127.100128 },
    { "id": "daiso-yeouido",      "name": "다이소 여의도점",   "latitude": 37.521624, "longitude": 126.924191 },
    { "id": "daiso-seolleung",    "name": "다이소 선릉역점",   "latitude": 37.504503, "longitude": 127.048963 },
    { "id": "daiso-konkuk",       "name": "다이소 건대입구점", "latitude": 37.540398, "longitude": 127.069221 }
  ]
}
```

- [ ] **Step 4: 템플릿 테스트 제거 및 분석**

```bash
rm test/widget_test.dart
flutter pub get
flutter analyze
```

Expected: `flutter analyze` → "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/data/stores_seed.json
git rm test/widget_test.dart
git commit -m "chore: add core-loop dependencies and store seed data"
```

---

### Task 2: Drift DB + 테이블 정의

**Files:**
- Create: `lib/core/db/app_database.dart`
- Create (생성): `lib/core/db/app_database.g.dart`
- Test: `test/core/db/app_database_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class AppDatabase extends _$AppDatabase` — 생성자 `AppDatabase(QueryExecutor e)`, 이름있는 생성자 `AppDatabase.forTesting(QueryExecutor e)`.
  - 테이블 `ShoppingItems`(컬럼: `id` int autoIncrement PK, `name` text, `quantity` int default 1, `isDone` bool default false, `createdAt` datetime), `Stores`(컬럼: `id` text PK, `name` text, `latitude` real, `longitude` real).
  - Drift 생성 데이터 클래스 `ShoppingItem`(row), `Store`(row) 및 companion.
  - `schemaVersion == 1`.

- [ ] **Step 1: Write the failing test**

`test/core/db/app_database_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('opens in-memory database with schema version 1', () async {
    expect(db.schemaVersion, 1);
  });

  test('shopping_items table starts empty', () async {
    final rows = await db.select(db.shoppingItems).get();
    expect(rows, isEmpty);
  });

  test('stores table starts empty', () async {
    final rows = await db.select(db.stores).get();
    expect(rows, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/db/app_database_test.dart`
Expected: FAIL — `app_database.dart` / 심볼 미존재로 컴파일 실패.

- [ ] **Step 3: Write the table + database definition**

`lib/core/db/app_database.dart`:

```dart
import 'package:drift/drift.dart';

part 'app_database.g.dart';

class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ShoppingItems, Stores])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 4: 코드 생성**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/core/db/app_database.g.dart` 생성, 오류 없음.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/db/app_database_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/core/db/app_database.dart lib/core/db/app_database.g.dart test/core/db/app_database_test.dart
git commit -m "feat: add Drift database with shopping_items and stores tables"
```

---

### Task 3: 쇼핑 아이템 repository (CRUD + watch)

**Files:**
- Create: `lib/features/shopping_list/data/shopping_item_repository.dart`
- Test: `test/features/shopping_list/shopping_item_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, Drift row 타입 `ShoppingItem`, companion `ShoppingItemsCompanion` (Task 2).
- Produces: `class ShoppingItemRepository`
  - `ShoppingItemRepository(AppDatabase db)`
  - `Future<int> add({required String name, int quantity = 1})` → 생성된 row id 반환. `createdAt`은 `DateTime.now()`.
  - `Future<void> toggleDone(int id, bool isDone)`
  - `Future<void> updateItem(int id, {String? name, int? quantity})`
  - `Future<void> delete(int id)`
  - `Future<List<ShoppingItem>> getAll()` (createdAt 오름차순)
  - `Stream<List<ShoppingItem>> watchAll()` (createdAt 오름차순)

- [ ] **Step 1: Write the failing test**

`test/features/shopping_list/shopping_item_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/db/app_database.dart';
import 'package:daijo/features/shopping_list/data/shopping_item_repository.dart';

void main() {
  late AppDatabase db;
  late ShoppingItemRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ShoppingItemRepository(db);
  });
  tearDown(() => db.close());

  test('add inserts an item and returns its id', () async {
    final id = await repo.add(name: '수세미', quantity: 2);
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.name, '수세미');
    expect(all.single.quantity, 2);
    expect(all.single.isDone, isFalse);
  });

  test('toggleDone updates completion flag', () async {
    final id = await repo.add(name: '건전지');
    await repo.toggleDone(id, true);
    expect((await repo.getAll()).single.isDone, isTrue);
  });

  test('updateItem changes name and quantity', () async {
    final id = await repo.add(name: '수세미', quantity: 1);
    await repo.updateItem(id, name: '철수세미', quantity: 3);
    final item = (await repo.getAll()).single;
    expect(item.name, '철수세미');
    expect(item.quantity, 3);
  });

  test('delete removes the item', () async {
    final id = await repo.add(name: '건전지');
    await repo.delete(id);
    expect(await repo.getAll(), isEmpty);
  });

  test('watchAll emits current items ordered by createdAt', () async {
    await repo.add(name: 'A');
    await repo.add(name: 'B');
    final first = await repo.watchAll().first;
    expect(first.map((e) => e.name), ['A', 'B']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/shopping_list/shopping_item_repository_test.dart`
Expected: FAIL — `ShoppingItemRepository` 미정의.

- [ ] **Step 3: Write the repository**

`lib/features/shopping_list/data/shopping_item_repository.dart`:

```dart
import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';

class ShoppingItemRepository {
  ShoppingItemRepository(this._db);

  final AppDatabase _db;

  Future<int> add({required String name, int quantity = 1}) {
    return _db.into(_db.shoppingItems).insert(
          ShoppingItemsCompanion.insert(
            name: name,
            quantity: Value(quantity),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> toggleDone(int id, bool isDone) {
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(isDone: Value(isDone)));
  }

  Future<void> updateItem(int id, {String? name, int? quantity}) {
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id))).write(
      ShoppingItemsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        quantity: quantity == null ? const Value.absent() : Value(quantity),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.shoppingItems)..where((t) => t.id.equals(id))).go();
  }

  Future<List<ShoppingItem>> getAll() {
    return (_db.select(_db.shoppingItems)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Stream<List<ShoppingItem>> watchAll() {
    return (_db.select(_db.shoppingItems)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/shopping_list/shopping_item_repository_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/shopping_list/data/shopping_item_repository.dart test/features/shopping_list/shopping_item_repository_test.dart
git commit -m "feat: add shopping item repository with CRUD and watch"
```

---

### Task 4: 매장 시드 로더 (JSON 파싱 + 멱등 적재)

**Files:**
- Create: `lib/features/stores/domain/store.dart`
- Create: `lib/features/stores/data/store_seed_loader.dart`
- Create: `lib/features/stores/data/store_repository.dart`
- Test: `test/features/stores/store_seed_loader_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, Drift `StoresCompanion` (Task 2).
- Produces:
  - `class StoreSeed { final String id; final String name; final double latitude; final double longitude; }` + `factory StoreSeed.fromJson(Map<String,dynamic>)`.
  - `List<StoreSeed> parseStoreSeeds(String jsonString)` — 최상위 `stores` 배열 파싱.
  - `class StoreSeedLoader` — `StoreSeedLoader(AppDatabase db)`, `Future<int> loadIfEmpty(String jsonString)` → **stores 테이블이 비어 있을 때만** 삽입, 삽입한 개수 반환(이미 채워졌으면 0).
  - `class StoreRepository` — `StoreRepository(AppDatabase db)`, `Future<List<Store>> getAll()`. (Drift row 타입 `Store` 사용)

- [ ] **Step 1: Write the failing test**

`test/features/stores/store_seed_loader_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/db/app_database.dart';
import 'package:daijo/features/stores/data/store_seed_loader.dart';
import 'package:daijo/features/stores/data/store_repository.dart';

const _json = '''
{ "version": 1, "stores": [
  { "id": "s1", "name": "매장1", "latitude": 37.5, "longitude": 127.0 },
  { "id": "s2", "name": "매장2", "latitude": 37.6, "longitude": 127.1 }
]}''';

void main() {
  late AppDatabase db;
  late StoreSeedLoader loader;
  late StoreRepository stores;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loader = StoreSeedLoader(db);
    stores = StoreRepository(db);
  });
  tearDown(() => db.close());

  test('parseStoreSeeds reads the stores array', () {
    final seeds = parseStoreSeeds(_json);
    expect(seeds, hasLength(2));
    expect(seeds.first.id, 's1');
    expect(seeds.first.latitude, 37.5);
  });

  test('loadIfEmpty inserts seeds into empty table', () async {
    final inserted = await loader.loadIfEmpty(_json);
    expect(inserted, 2);
    expect(await stores.getAll(), hasLength(2));
  });

  test('loadIfEmpty is idempotent when table already populated', () async {
    await loader.loadIfEmpty(_json);
    final second = await loader.loadIfEmpty(_json);
    expect(second, 0);
    expect(await stores.getAll(), hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/stores/store_seed_loader_test.dart`
Expected: FAIL — 심볼 미정의.

- [ ] **Step 3: Write domain + loader + repository**

`lib/features/stores/domain/store.dart`:

```dart
class StoreSeed {
  const StoreSeed({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  factory StoreSeed.fromJson(Map<String, dynamic> json) => StoreSeed(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}
```

`lib/features/stores/data/store_seed_loader.dart`:

```dart
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../domain/store.dart';

List<StoreSeed> parseStoreSeeds(String jsonString) {
  final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
  final list = decoded['stores'] as List<dynamic>;
  return list
      .map((e) => StoreSeed.fromJson(e as Map<String, dynamic>))
      .toList();
}

class StoreSeedLoader {
  StoreSeedLoader(this._db);

  final AppDatabase _db;

  Future<int> loadIfEmpty(String jsonString) async {
    final existing = await _db.select(_db.stores).get();
    if (existing.isNotEmpty) return 0;

    final seeds = parseStoreSeeds(jsonString);
    await _db.batch((b) {
      b.insertAll(
        _db.stores,
        seeds.map(
          (s) => StoresCompanion.insert(
            id: s.id,
            name: s.name,
            latitude: s.latitude,
            longitude: s.longitude,
          ),
        ),
      );
    });
    return seeds.length;
  }
}
```

`lib/features/stores/data/store_repository.dart`:

```dart
import '../../../core/db/app_database.dart';

class StoreRepository {
  StoreRepository(this._db);

  final AppDatabase _db;

  Future<List<Store>> getAll() => _db.select(_db.stores).get();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/stores/store_seed_loader_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/stores/domain/store.dart lib/features/stores/data/store_seed_loader.dart lib/features/stores/data/store_repository.dart test/features/stores/store_seed_loader_test.dart
git commit -m "feat: add store seed loader with idempotent DB load"
```

---

### Task 5: 가까운 N개 매장 선별 (Haversine 거리)

**Files:**
- Create: `lib/features/stores/application/geo_math.dart`
- Test: `test/features/stores/geo_math_test.dart`

**Interfaces:**
- Consumes: Drift row 타입 `Store`(Task 2: `id, name, latitude, longitude`).
- Produces:
  - `double distanceMeters(double lat1, double lng1, double lat2, double lng2)` — Haversine, 미터 단위.
  - `List<Store> selectNearest(List<Store> stores, double lat, double lng, int n)` — 거리 오름차순 정렬 후 상위 `n`개. `n`이 개수보다 크면 전부 반환.

- [ ] **Step 1: Write the failing test**

`test/features/stores/geo_math_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/db/app_database.dart';
import 'package:daijo/features/stores/application/geo_math.dart';

Store _store(String id, double lat, double lng) =>
    Store(id: id, name: id, latitude: lat, longitude: lng);

void main() {
  test('distanceMeters ~111km per degree of latitude', () {
    final d = distanceMeters(37.0, 127.0, 38.0, 127.0);
    expect(d, closeTo(111000, 2000));
  });

  test('distanceMeters is zero for identical points', () {
    expect(distanceMeters(37.5, 127.0, 37.5, 127.0), closeTo(0, 0.001));
  });

  test('selectNearest returns n closest ordered by distance', () {
    final stores = [
      _store('far', 40.0, 127.0),
      _store('near', 37.51, 127.0),
      _store('mid', 37.7, 127.0),
    ];
    final result = selectNearest(stores, 37.5, 127.0, 2);
    expect(result.map((s) => s.id), ['near', 'mid']);
  });

  test('selectNearest returns all when n exceeds count', () {
    final stores = [_store('a', 37.5, 127.0), _store('b', 37.6, 127.0)];
    expect(selectNearest(stores, 37.5, 127.0, 20), hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/stores/geo_math_test.dart`
Expected: FAIL — `distanceMeters`/`selectNearest` 미정의.

- [ ] **Step 3: Write the implementation**

`lib/features/stores/application/geo_math.dart`:

```dart
import 'dart:math' as math;
import '../../../core/db/app_database.dart';

const double _earthRadiusMeters = 6371000;

double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusMeters * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;

List<Store> selectNearest(
  List<Store> stores,
  double lat,
  double lng,
  int n,
) {
  final sorted = [...stores]..sort(
      (a, b) => distanceMeters(lat, lng, a.latitude, a.longitude)
          .compareTo(distanceMeters(lat, lng, b.latitude, b.longitude)),
    );
  return sorted.take(n).toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/stores/geo_math_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/stores/application/geo_math.dart test/features/stores/geo_math_test.dart
git commit -m "feat: add haversine distance and nearest-N store selection"
```

---

### Task 6: 알림 서비스 인터페이스 + 페이로드 빌더

**Files:**
- Create: `lib/core/notifications/notification_service.dart`
- Create: `lib/core/notifications/notification_payload_builder.dart`
- Test: `test/core/notifications/notification_payload_builder_test.dart`

**Interfaces:**
- Consumes: Drift row 타입 `ShoppingItem`(Task 2).
- Produces:
  - `class NotificationContent { final String title; final String body; const NotificationContent({required this.title, required this.body}); }` + `==`/`hashCode`.
  - `NotificationContent? buildShoppingReminder({required String storeName, required List<ShoppingItem> items})` — **완료되지 않은(isDone=false) 아이템만** 요약. 미완료 아이템이 없으면 `null`(알림 억제). title=`"$storeName 근처예요"`, body=미완료 아이템 이름을 최대 3개 `", "`로 연결하고 초과분은 ` 외 N개`.
  - `abstract interface class NotificationService { Future<void> initialize(); Future<void> showReminder(NotificationContent content); }`

- [ ] **Step 1: Write the failing test**

`test/core/notifications/notification_payload_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/db/app_database.dart';
import 'package:daijo/core/notifications/notification_payload_builder.dart';

ShoppingItem _item(String name, {bool done = false}) => ShoppingItem(
      id: name.hashCode,
      name: name,
      quantity: 1,
      isDone: done,
      createdAt: DateTime(2026),
    );

void main() {
  test('returns null when there are no pending items', () {
    final result = buildShoppingReminder(
      storeName: '다이소 강남역점',
      items: [_item('수세미', done: true)],
    );
    expect(result, isNull);
  });

  test('summarizes up to three pending item names', () {
    final result = buildShoppingReminder(
      storeName: '다이소 강남역점',
      items: [_item('수세미'), _item('건전지'), _item('물티슈')],
    );
    expect(result!.title, '다이소 강남역점 근처예요');
    expect(result.body, '수세미, 건전지, 물티슈');
  });

  test('adds overflow suffix beyond three items', () {
    final result = buildShoppingReminder(
      storeName: '다이소',
      items: [_item('a'), _item('b'), _item('c'), _item('d'), _item('e')],
    );
    expect(result!.body, 'a, b, c 외 2개');
  });

  test('ignores completed items in the summary', () {
    final result = buildShoppingReminder(
      storeName: '다이소',
      items: [_item('수세미', done: true), _item('건전지')],
    );
    expect(result!.body, '건전지');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/notifications/notification_payload_builder_test.dart`
Expected: FAIL — 심볼 미정의.

- [ ] **Step 3: Write interface + builder**

`lib/core/notifications/notification_service.dart`:

```dart
class NotificationContent {
  const NotificationContent({required this.title, required this.body});

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is NotificationContent &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

abstract interface class NotificationService {
  Future<void> initialize();
  Future<void> showReminder(NotificationContent content);
}
```

`lib/core/notifications/notification_payload_builder.dart`:

```dart
import '../db/app_database.dart';
import 'notification_service.dart';

NotificationContent? buildShoppingReminder({
  required String storeName,
  required List<ShoppingItem> items,
}) {
  final pending = items.where((i) => !i.isDone).toList();
  if (pending.isEmpty) return null;

  final names = pending.map((i) => i.name).toList();
  final shown = names.take(3).join(', ');
  final body = names.length > 3 ? '$shown 외 ${names.length - 3}개' : shown;

  return NotificationContent(title: '$storeName 근처예요', body: body);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/notifications/notification_payload_builder_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/notifications/notification_service.dart lib/core/notifications/notification_payload_builder.dart test/core/notifications/notification_payload_builder_test.dart
git commit -m "feat: add notification service interface and reminder payload builder"
```

---

### Task 7: 위치 서비스 인터페이스 + geolocator 구현

**Files:**
- Create: `lib/core/location/location_service.dart`
- Create: `lib/core/location/geolocator_location_service.dart`
- Test: `test/core/location/location_service_test.dart`

**Interfaces:**
- Consumes: 없음(도메인 값 타입은 자체 정의).
- Produces:
  - `class GeoPoint { final double latitude; final double longitude; const GeoPoint(this.latitude, this.longitude); }`
  - `enum LocationPermissionStatus { granted, whileInUse, denied }`
  - `abstract interface class LocationService { Future<LocationPermissionStatus> requestPermission(); Future<GeoPoint?> currentPosition(); }`
  - `class GeolocatorLocationService implements LocationService` — concrete(geolocator/permission_handler). **기기 수동 테스트 대상**; 유닛 테스트는 인터페이스+값 타입만 검증.

- [ ] **Step 1: Write the failing test**

`test/core/location/location_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/location/location_service.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService(this._status, this._point);
  final LocationPermissionStatus _status;
  final GeoPoint? _point;

  @override
  Future<LocationPermissionStatus> requestPermission() async => _status;

  @override
  Future<GeoPoint?> currentPosition() async => _point;
}

void main() {
  test('GeoPoint stores coordinates', () {
    const p = GeoPoint(37.5, 127.0);
    expect(p.latitude, 37.5);
    expect(p.longitude, 127.0);
  });

  test('LocationService fake returns configured values', () async {
    final svc = _FakeLocationService(
      LocationPermissionStatus.granted,
      const GeoPoint(37.5, 127.0),
    );
    expect(await svc.requestPermission(), LocationPermissionStatus.granted);
    expect((await svc.currentPosition())!.latitude, 37.5);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/location/location_service_test.dart`
Expected: FAIL — 심볼 미정의.

- [ ] **Step 3: Write interface**

`lib/core/location/location_service.dart`:

```dart
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

enum LocationPermissionStatus { granted, whileInUse, denied }

abstract interface class LocationService {
  /// 위치 권한을 요청하고 최종 상태를 반환한다.
  Future<LocationPermissionStatus> requestPermission();

  /// 현재 좌표. 권한이 없거나 취득 실패 시 null.
  Future<GeoPoint?> currentPosition();
}
```

- [ ] **Step 4: Write the concrete implementation**

`lib/core/location/geolocator_location_service.dart`:

```dart
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationPermissionStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStatus.denied;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
        return LocationPermissionStatus.granted;
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.whileInUse;
      case LocationPermission.denied:
      case LocationPermission.deniedForever:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<GeoPoint?> currentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 5: Run test + analyze**

Run: `flutter test test/core/location/location_service_test.dart && flutter analyze`
Expected: PASS (2 tests), analyze 무경고.

- [ ] **Step 6: Commit**

```bash
git add lib/core/location/location_service.dart lib/core/location/geolocator_location_service.dart test/core/location/location_service_test.dart
git commit -m "feat: add location service interface and geolocator implementation"
```

---

### Task 8: 지오펜스 서비스 인터페이스 + native_geofence 구현

**Files:**
- Create: `lib/core/geofence/geofence_service.dart`
- Create: `lib/core/geofence/native_geofence_service.dart`
- Test: `test/core/geofence/geofence_service_test.dart`

**Interfaces:**
- Consumes: 없음(자체 값 타입).
- Produces:
  - `class GeofenceRegion { final String id; final double latitude; final double longitude; final double radiusMeters; const GeofenceRegion({...}); }`
  - `abstract interface class GeofenceService { Future<void> initialize(); Future<void> replaceAll(List<GeofenceRegion> regions); Future<void> clearAll(); }`
  - `class NativeGeofenceService implements GeofenceService` — concrete(native_geofence). **기기 수동 테스트 대상.**
  - 최상위 백그라운드 콜백 `@pragma('vm:entry-point') Future<void> daijoGeofenceCallback(GeofenceCallbackParams params)` (Task 12 Step 7에서 알림 발화 로직 연결).

> **참고(API 확인됨, native_geofence 1.3.x):** `NativeGeofenceManager.instance.initialize()`, `.createGeofence(Geofence, callback)`, `.removeAllGeofences()`. `Geofence({required String id, required Location location, required double radiusMeters, required Set<GeofenceEvent> triggers, required IosGeofenceSettings iosSettings, required AndroidGeofenceSettings androidSettings})`. `Location(latitude:, longitude:)`, `GeofenceEvent.enter`, `AndroidGeofenceSettings(initialTriggers: {...})`, `IosGeofenceSettings(initialTrigger: false)`. `GeofenceCallbackParams{event, geofences: List<ActiveGeofence>, location}`. **설치된 패키지 버전의 정확한 필드명을 구현 직전 `.../hosted/pub.dev/native_geofence-*/lib/` 에서 재확인할 것.**

- [ ] **Step 1: Write the failing test (인터페이스 + fake 계약)**

`test/core/geofence/geofence_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/geofence/geofence_service.dart';

class _FakeGeofenceService implements GeofenceService {
  final List<GeofenceRegion> active = [];
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<void> replaceAll(List<GeofenceRegion> regions) async {
    active
      ..clear()
      ..addAll(regions);
  }

  @override
  Future<void> clearAll() async => active.clear();
}

void main() {
  test('GeofenceRegion holds its fields', () {
    const r = GeofenceRegion(
      id: 's1',
      latitude: 37.5,
      longitude: 127.0,
      radiusMeters: 150,
    );
    expect(r.id, 's1');
    expect(r.radiusMeters, 150);
  });

  test('replaceAll swaps the active set; clearAll empties it', () async {
    final svc = _FakeGeofenceService();
    await svc.replaceAll(const [
      GeofenceRegion(id: 'a', latitude: 1, longitude: 2, radiusMeters: 150),
    ]);
    expect(svc.active, hasLength(1));
    await svc.clearAll();
    expect(svc.active, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/geofence/geofence_service_test.dart`
Expected: FAIL — 심볼 미정의.

- [ ] **Step 3: Write interface + value type**

`lib/core/geofence/geofence_service.dart`:

```dart
class GeofenceRegion {
  const GeofenceRegion({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double radiusMeters;
}

abstract interface class GeofenceService {
  Future<void> initialize();

  /// 기존 지오펜스를 모두 제거하고 [regions]로 교체 등록한다.
  Future<void> replaceAll(List<GeofenceRegion> regions);

  Future<void> clearAll();
}
```

- [ ] **Step 4: Write the concrete implementation**

`lib/core/geofence/native_geofence_service.dart`:

```dart
import 'package:native_geofence/native_geofence.dart';
import 'geofence_service.dart';

/// 백그라운드 격리 진입점. Task 12 Step 7에서 알림 발화 로직을 채운다.
@pragma('vm:entry-point')
Future<void> daijoGeofenceCallback(GeofenceCallbackParams params) async {
  // Task 12 Step 7에서 구현: params.geofences에서 매장명 조회 → 목록 요약 알림.
}

class NativeGeofenceService implements GeofenceService {
  @override
  Future<void> initialize() =>
      NativeGeofenceManager.instance.initialize();

  @override
  Future<void> clearAll() =>
      NativeGeofenceManager.instance.removeAllGeofences();

  @override
  Future<void> replaceAll(List<GeofenceRegion> regions) async {
    await NativeGeofenceManager.instance.removeAllGeofences();
    for (final r in regions) {
      final geofence = Geofence(
        id: r.id,
        location: Location(latitude: r.latitude, longitude: r.longitude),
        radiusMeters: r.radiusMeters,
        triggers: const {GeofenceEvent.enter},
        iosSettings: const IosGeofenceSettings(initialTrigger: false),
        androidSettings: const AndroidGeofenceSettings(
          initialTriggers: {GeofenceEvent.enter},
        ),
      );
      await NativeGeofenceManager.instance
          .createGeofence(geofence, daijoGeofenceCallback);
    }
  }
}
```

- [ ] **Step 5: Run test + analyze**

Run: `flutter test test/core/geofence/geofence_service_test.dart && flutter analyze`
Expected: PASS (2 tests), analyze 무경고. (import된 native_geofence 심볼명이 다르면 설치 버전 소스에 맞춰 수정)

- [ ] **Step 6: Commit**

```bash
git add lib/core/geofence/geofence_service.dart lib/core/geofence/native_geofence_service.dart test/core/geofence/geofence_service_test.dart
git commit -m "feat: add geofence service interface and native_geofence implementation"
```

---

### Task 9: GeofenceManager — 가까운 20개 재선별·재등록 오케스트레이션

**Files:**
- Create: `lib/features/stores/application/geofence_manager.dart`
- Create: `test/support/fakes.dart`
- Test: `test/features/stores/geofence_manager_test.dart`

**Interfaces:**
- Consumes: `StoreRepository.getAll()` (Task 4), `LocationService` (Task 7), `GeofenceService`/`GeofenceRegion` (Task 8), `selectNearest` (Task 5), Drift `Store` (Task 2).
- Produces:
  - `class GeofenceManager` — 생성자 `GeofenceManager({required StoreRepository stores, required LocationService location, required GeofenceService geofence, int nearestCount = 20, double radiusMeters = 150})`.
  - `Future<GeofenceSyncResult> syncNearbyStores()` — ① 위치 취득(null이면 등록 안 함, `GeofenceSyncResult.noLocation`) ② 매장 전체 로드 ③ `selectNearest(...,20)` ④ 각 매장→`GeofenceRegion(radius=150)` ⑤ `geofence.replaceAll(regions)` ⑥ `GeofenceSyncResult.registered(count)`.
  - `sealed class GeofenceSyncResult` with `GeofenceRegistered(int count)`, `GeofenceNoLocation`.
- Produces (fakes, 후속 태스크 공유): `test/support/fakes.dart` — `FakeLocationService`, `FakeGeofenceService`, `FakeNotificationService`.

- [ ] **Step 1: Write shared fakes**

`test/support/fakes.dart`:

```dart
import 'package:daijo/core/geofence/geofence_service.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/core/notifications/notification_service.dart';

class FakeLocationService implements LocationService {
  FakeLocationService({this.status = LocationPermissionStatus.granted, this.point});
  LocationPermissionStatus status;
  GeoPoint? point;

  @override
  Future<LocationPermissionStatus> requestPermission() async => status;

  @override
  Future<GeoPoint?> currentPosition() async => point;
}

class FakeGeofenceService implements GeofenceService {
  final List<GeofenceRegion> active = [];
  bool initialized = false;
  int replaceCallCount = 0;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<void> replaceAll(List<GeofenceRegion> regions) async {
    replaceCallCount++;
    active
      ..clear()
      ..addAll(regions);
  }

  @override
  Future<void> clearAll() async => active.clear();
}

class FakeNotificationService implements NotificationService {
  final List<NotificationContent> shown = [];
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<void> showReminder(NotificationContent content) async =>
      shown.add(content);
}
```

- [ ] **Step 2: Write the failing test**

`test/features/stores/geofence_manager_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/db/app_database.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/features/stores/application/geofence_manager.dart';
import 'package:daijo/features/stores/data/store_repository.dart';
import '../../support/fakes.dart';

Future<void> _seed(AppDatabase db, int count) async {
  for (var i = 0; i < count; i++) {
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: 's$i',
            name: 'store$i',
            latitude: 37.5 + i * 0.001,
            longitude: 127.0,
          ),
        );
  }
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('registers nearest 20 with 150m radius when position available', () async {
    await _seed(db, 30);
    final geofence = FakeGeofenceService();
    final manager = GeofenceManager(
      stores: StoreRepository(db),
      location: FakeLocationService(point: const GeoPoint(37.5, 127.0)),
      geofence: geofence,
    );

    final result = await manager.syncNearbyStores();

    expect(result, isA<GeofenceRegistered>());
    expect((result as GeofenceRegistered).count, 20);
    expect(geofence.active, hasLength(20));
    expect(geofence.active.every((r) => r.radiusMeters == 150), isTrue);
  });

  test('does nothing and reports noLocation when position is null', () async {
    await _seed(db, 5);
    final geofence = FakeGeofenceService();
    final manager = GeofenceManager(
      stores: StoreRepository(db),
      location: FakeLocationService(point: null),
      geofence: geofence,
    );

    final result = await manager.syncNearbyStores();

    expect(result, isA<GeofenceNoLocation>());
    expect(geofence.replaceCallCount, 0);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/stores/geofence_manager_test.dart`
Expected: FAIL — 심볼 미정의.

- [ ] **Step 4: Write the manager**

`lib/features/stores/application/geofence_manager.dart`:

```dart
import '../../../core/geofence/geofence_service.dart';
import '../../../core/location/location_service.dart';
import '../data/store_repository.dart';
import 'geo_math.dart';

sealed class GeofenceSyncResult {
  const GeofenceSyncResult();
}

class GeofenceRegistered extends GeofenceSyncResult {
  const GeofenceRegistered(this.count);
  final int count;
}

class GeofenceNoLocation extends GeofenceSyncResult {
  const GeofenceNoLocation();
}

class GeofenceManager {
  GeofenceManager({
    required StoreRepository stores,
    required LocationService location,
    required GeofenceService geofence,
    this.nearestCount = 20,
    this.radiusMeters = 150,
  })  : _stores = stores,
        _location = location,
        _geofence = geofence;

  final StoreRepository _stores;
  final LocationService _location;
  final GeofenceService _geofence;
  final int nearestCount;
  final double radiusMeters;

  Future<GeofenceSyncResult> syncNearbyStores() async {
    final point = await _location.currentPosition();
    if (point == null) return const GeofenceNoLocation();

    final all = await _stores.getAll();
    final nearest =
        selectNearest(all, point.latitude, point.longitude, nearestCount);

    final regions = nearest
        .map((s) => GeofenceRegion(
              id: s.id,
              latitude: s.latitude,
              longitude: s.longitude,
              radiusMeters: radiusMeters,
            ))
        .toList();

    await _geofence.replaceAll(regions);
    return GeofenceRegistered(regions.length);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/stores/geofence_manager_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/features/stores/application/geofence_manager.dart test/support/fakes.dart test/features/stores/geofence_manager_test.dart
git commit -m "feat: add geofence manager to sync nearest 20 stores"
```

---

### Task 10: Riverpod providers + 쇼핑 목록 컨트롤러

**Files:**
- Create: `lib/providers.dart`
- Create: `lib/features/shopping_list/presentation/shopping_list_controller.dart`
- Test: `test/features/shopping_list/shopping_list_controller_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`(Task 2), `ShoppingItemRepository`(Task 3), Drift `ShoppingItem`.
- Produces:
  - `lib/providers.dart`:
    - `final appDatabaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError())` — `main.dart`에서 override.
    - `final shoppingItemRepositoryProvider = Provider<ShoppingItemRepository>((ref) => ShoppingItemRepository(ref.watch(appDatabaseProvider)));`
  - `lib/features/shopping_list/presentation/shopping_list_controller.dart`:
    - `final shoppingListControllerProvider = StreamProvider<List<ShoppingItem>>((ref) => ref.watch(shoppingItemRepositoryProvider).watchAll());`
    - `class ShoppingListActions` + `final shoppingListActionsProvider = Provider<ShoppingListActions>(...)` — `add/toggleDone/updateItem/delete`를 repository로 위임.

- [ ] **Step 1: Write the failing test**

`test/features/shopping_list/shopping_list_controller_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/db/app_database.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_controller.dart';
import 'package:daijo/providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('actions.add then stream emits the item', () async {
    await container.read(shoppingListActionsProvider).add(name: '수세미');
    final items = await container.read(shoppingListControllerProvider.future);
    expect(items.single.name, '수세미');
  });

  test('actions.toggleDone updates the item', () async {
    final actions = container.read(shoppingListActionsProvider);
    await actions.add(name: '건전지');
    final id = (await container.read(shoppingListControllerProvider.future))
        .single
        .id;
    await actions.toggleDone(id, true);
    final items = await container.read(shoppingListControllerProvider.future);
    expect(items.single.isDone, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/shopping_list/shopping_list_controller_test.dart`
Expected: FAIL — 심볼 미정의.

- [ ] **Step 3: Write providers**

`lib/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/db/app_database.dart';
import 'features/shopping_list/data/shopping_item_repository.dart';

/// main.dart에서 실제 인스턴스로 override 한다.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

final shoppingItemRepositoryProvider = Provider<ShoppingItemRepository>(
  (ref) => ShoppingItemRepository(ref.watch(appDatabaseProvider)),
);
```

- [ ] **Step 4: Write the controller**

`lib/features/shopping_list/presentation/shopping_list_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../../../providers.dart';
import '../data/shopping_item_repository.dart';

final shoppingListControllerProvider =
    StreamProvider<List<ShoppingItem>>((ref) {
  return ref.watch(shoppingItemRepositoryProvider).watchAll();
});

class ShoppingListActions {
  ShoppingListActions(this._repo);
  final ShoppingItemRepository _repo;

  Future<void> add({required String name, int quantity = 1}) =>
      _repo.add(name: name, quantity: quantity);
  Future<void> toggleDone(int id, bool isDone) => _repo.toggleDone(id, isDone);
  Future<void> updateItem(int id, {String? name, int? quantity}) =>
      _repo.updateItem(id, name: name, quantity: quantity);
  Future<void> delete(int id) => _repo.delete(id);
}

final shoppingListActionsProvider = Provider<ShoppingListActions>(
  (ref) => ShoppingListActions(ref.watch(shoppingItemRepositoryProvider)),
);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/shopping_list/shopping_list_controller_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/providers.dart lib/features/shopping_list/presentation/shopping_list_controller.dart test/features/shopping_list/shopping_list_controller_test.dart
git commit -m "feat: add riverpod providers and shopping list controller"
```

---

### Task 11: 쇼핑 목록 화면 (UI)

**Files:**
- Create: `lib/features/shopping_list/presentation/shopping_list_screen.dart`
- Test: `test/features/shopping_list/shopping_list_screen_test.dart`

**Interfaces:**
- Consumes: `shoppingListControllerProvider`, `shoppingListActionsProvider`(Task 10), `appDatabaseProvider`(Task 10), Drift `ShoppingItem`.
- Produces: `class ShoppingListScreen extends ConsumerWidget` — AppBar 제목 `"다잊어"`, 목록 `ListView`(각 항목: `Checkbox`(isDone) + 이름 + 수량, 밀어서 삭제 `Dismissible`), FAB(`+`) 탭 시 `showDialog`로 이름 입력 후 `add`. 빈 상태 안내 텍스트 `"살 물건을 추가하세요"`. 각 항목 `Checkbox`에 `key: ValueKey('item-check-${item.id}')`, 항목 타일에 `key: ValueKey('item-${item.id}')`.

- [ ] **Step 1: Write the failing widget test**

`test/features/shopping_list/shopping_list_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/db/app_database.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_screen.dart';
import 'package:daijo/providers.dart';

Widget _app(AppDatabase db) => ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: ShoppingListScreen()),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('shows empty-state message when list is empty', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    expect(find.text('살 물건을 추가하세요'), findsOneWidget);
  });

  testWidgets('adds an item through the dialog', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '수세미');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.text('수세미'), findsOneWidget);
  });

  testWidgets('checkbox toggles completion', (tester) async {
    await ShoppingItemRepositoryHarness(db).add('건전지');
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('item-check-1')));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('item-check-1')),
    );
    expect(checkbox.value, isTrue);
  });
}
```

`ShoppingItemRepositoryHarness`는 테스트 편의 헬퍼다. 같은 파일 하단에 정의:

```dart
class ShoppingItemRepositoryHarness {
  ShoppingItemRepositoryHarness(this.db);
  final AppDatabase db;
  Future<void> add(String name) => db.into(db.shoppingItems).insert(
        ShoppingItemsCompanion.insert(name: name, createdAt: DateTime(2026)),
      );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/shopping_list/shopping_list_screen_test.dart`
Expected: FAIL — `ShoppingListScreen` 미정의.

- [ ] **Step 3: Write the screen**

`lib/features/shopping_list/presentation/shopping_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shopping_list_controller.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingListControllerProvider);
    final actions = ref.watch(shoppingListActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('다잊어')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('살 물건을 추가하세요'));
          }
          return ListView(
            children: [
              for (final item in items)
                Dismissible(
                  key: ValueKey('item-${item.id}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => actions.delete(item.id),
                  background: Container(color: Colors.red),
                  child: CheckboxListTile(
                    key: ValueKey('item-check-${item.id}'),
                    value: item.isDone,
                    onChanged: (v) => actions.toggleDone(item.id, v ?? false),
                    title: Text(item.name),
                    subtitle: item.quantity > 1
                        ? Text('수량 ${item.quantity}')
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, actions),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    ShoppingListActions actions,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('살 물건'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 수세미'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) actions.add(name: name);
              Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}
```

> **참고:** `CheckboxListTile`은 tester가 찾도록 `key`를 직접 받는다. 위 `find.byKey('item-check-1')`가 `CheckboxListTile`을 가리키므로, 테스트의 `tester.widget<Checkbox>`는 `CheckboxListTile`로 바꾼다. — Step 4에서 테스트를 실제 위젯 타입에 맞춰 조정할 것(아래).

- [ ] **Step 4: 테스트를 실제 위젯 타입에 맞춰 조정**

Step 1 테스트의 마지막 케이스에서 `Checkbox` → `CheckboxListTile`로 수정:

```dart
    final tile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('item-check-1')),
    );
    expect(tile.value, isTrue);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/shopping_list/shopping_list_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/features/shopping_list/presentation/shopping_list_screen.dart test/features/shopping_list/shopping_list_screen_test.dart
git commit -m "feat: add shopping list screen with add, toggle, delete"
```

---

### Task 12: 부트스트랩 + 앱 조립 + 알림/지오펜스 연결 (기기 검증)

**Files:**
- Create: `lib/bootstrap.dart`
- Create: `lib/core/notifications/flutter_local_notification_service.dart`
- Create: `lib/app.dart`
- Modify: `lib/main.dart` (템플릿 전체 교체)
- Modify: `lib/core/geofence/native_geofence_service.dart` (콜백 본문 구현)
- Modify: `android/app/src/main/AndroidManifest.xml` (권한/서비스)
- Test: `test/bootstrap_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`(2), `StoreSeedLoader`(4), `GeofenceManager`(9), `NotificationService`/`buildShoppingReminder`(6), `GeolocatorLocationService`(7), `NativeGeofenceService`(8), providers(10), `ShoppingListScreen`(11).
- Produces:
  - `class FlutterLocalNotificationService implements NotificationService` — concrete(flutter_local_notifications). **기기 검증.**
  - `Future<AppDatabase> openAppDatabase()` — `path_provider` 경로에 SQLite 파일 오픈(기기/통합 대상). 유닛 테스트 없음.
  - `Future<void> bootstrap({required AppDatabase db, required String seedJson, required GeofenceManager geofenceManager, required NotificationService notifications, required LocationService location})` — 시퀀스: 시드 적재 → 알림 init → 위치 권한 요청 → (권한 있으면) 지오펜스 initialize + `syncNearbyStores()`. **권한 없어도 예외 없이 완료**(목록 앱으로 계속 동작). 반환 없음. 이 함수의 "권한 없을 때 지오펜스 동기화를 호출하지 않는다"만 유닛 테스트한다.
  - `class DaijoApp extends StatelessWidget` — `MaterialApp(home: ShoppingListScreen())`.

- [ ] **Step 1: Write the failing test (부트스트랩 분기만)**

`test/bootstrap_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/bootstrap.dart';
import 'package:daijo/core/db/app_database.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/features/stores/application/geofence_manager.dart';
import 'package:daijo/features/stores/data/store_repository.dart';
import 'support/fakes.dart';

const _seed = '''
{ "version": 1, "stores": [
  { "id": "s1", "name": "매장1", "latitude": 37.5, "longitude": 127.0 }
]}''';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('loads seed and skips geofence sync when permission denied', () async {
    final geofence = FakeGeofenceService();
    final location = FakeLocationService(
      status: LocationPermissionStatus.denied,
      point: null,
    );
    final manager = GeofenceManager(
      stores: StoreRepository(db),
      location: location,
      geofence: geofence,
    );

    await bootstrap(
      db: db,
      seedJson: _seed,
      geofenceManager: manager,
      notifications: FakeNotificationService(),
      location: location,
    );

    expect(await StoreRepository(db).getAll(), hasLength(1));
    expect(geofence.replaceCallCount, 0);
  });

  test('syncs geofences when permission granted', () async {
    final geofence = FakeGeofenceService();
    final location = FakeLocationService(
      status: LocationPermissionStatus.granted,
      point: const GeoPoint(37.5, 127.0),
    );
    final manager = GeofenceManager(
      stores: StoreRepository(db),
      location: location,
      geofence: geofence,
    );

    await bootstrap(
      db: db,
      seedJson: _seed,
      geofenceManager: manager,
      notifications: FakeNotificationService(),
      location: location,
    );

    expect(geofence.initialized, isTrue);
    expect(geofence.replaceCallCount, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/bootstrap_test.dart`
Expected: FAIL — `bootstrap` 미정의.

- [ ] **Step 3: Write bootstrap**

`lib/bootstrap.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'core/db/app_database.dart';
import 'core/location/location_service.dart';
import 'core/notifications/notification_service.dart';
import 'features/stores/application/geofence_manager.dart';
import 'features/stores/data/store_seed_loader.dart';

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'daijo.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}

Future<void> bootstrap({
  required AppDatabase db,
  required String seedJson,
  required GeofenceManager geofenceManager,
  required NotificationService notifications,
  required LocationService location,
}) async {
  await StoreSeedLoader(db).loadIfEmpty(seedJson);
  await notifications.initialize();

  final status = await location.requestPermission();
  if (status == LocationPermissionStatus.denied) return;

  await geofenceManager.syncNearbyStores();
}
```

> **참고:** `GeofenceManager`에 지오펜스 `initialize()`를 부트스트랩에서 호출하려면, Task 9의 매니저에 `Future<void> initialize() => _geofence.initialize();`를 추가하고 bootstrap의 sync 직전에 호출한다. Step 3 구현 시 매니저에 이 메서드를 더하고, `bootstrap`에서 `await geofenceManager.initialize();`를 `syncNearbyStores()` 앞에 넣어 `FakeGeofenceService.initialized`가 참이 되게 한다.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/bootstrap_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Write concrete notification service (기기 검증)**

`lib/core/notifications/flutter_local_notification_service.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

class FlutterLocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'daijo_reminder';
  static const _channelName = '쇼핑 리마인더';

  @override
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> showReminder(NotificationContent content) async {
    await _plugin.show(
      0,
      content.title,
      content.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write app + main**

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'features/shopping_list/presentation/shopping_list_screen.dart';

class DaijoApp extends StatelessWidget {
  const DaijoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다잊어',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const ShoppingListScreen(),
    );
  }
}
```

`lib/main.dart` (템플릿 전체 교체):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/geofence/native_geofence_service.dart';
import 'core/location/geolocator_location_service.dart';
import 'core/notifications/flutter_local_notification_service.dart';
import 'features/stores/application/geofence_manager.dart';
import 'features/stores/data/store_repository.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await openAppDatabase();
  final seedJson =
      await rootBundle.loadString('assets/data/stores_seed.json');
  final location = GeolocatorLocationService();
  final geofenceManager = GeofenceManager(
    stores: StoreRepository(db),
    location: location,
    geofence: NativeGeofenceService(),
  );

  await bootstrap(
    db: db,
    seedJson: seedJson,
    geofenceManager: geofenceManager,
    notifications: FlutterLocalNotificationService(),
    location: location,
  );

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const DaijoApp(),
    ),
  );
}
```

- [ ] **Step 7: 지오펜스 콜백 본문 구현 (ENTER → 알림)**

`lib/core/geofence/native_geofence_service.dart`의 `daijoGeofenceCallback`을 채운다. 백그라운드 격리에서는 별도 DB/알림 인스턴스를 새로 연다:

```dart
@pragma('vm:entry-point')
Future<void> daijoGeofenceCallback(GeofenceCallbackParams params) async {
  if (params.event != GeofenceEvent.enter) return;

  final db = await openAppDatabase();
  try {
    final items = await ShoppingItemRepository(db).getAll();
    final triggered = params.geofences.isNotEmpty
        ? params.geofences.first.id
        : null;
    final store = triggered == null
        ? null
        : (await StoreRepository(db).getAll())
            .where((s) => s.id == triggered)
            .cast<Store?>()
            .firstWhere((s) => true, orElse: () => null);

    final content = buildShoppingReminder(
      storeName: store?.name ?? '다이소',
      items: items,
    );
    if (content == null) return; // 빈 목록/전부 완료 → 알림 억제

    final notifications = FlutterLocalNotificationService();
    await notifications.initialize();
    await notifications.showReminder(content);
  } finally {
    await db.close();
  }
}
```

필요한 import를 파일 상단에 추가: `openAppDatabase`(`../../bootstrap.dart`), `ShoppingItemRepository`, `StoreRepository`, `Store`(`app_database.dart`), `buildShoppingReminder`, `FlutterLocalNotificationService`.

- [ ] **Step 8: Android 매니페스트 권한/서비스**

`android/app/src/main/AndroidManifest.xml` `<manifest>` 안, `<application>` 위에 권한 추가:

```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

그리고 native_geofence README가 요구하는 `<receiver>`/`<service>` 등록을 설치 버전 README에 맞춰 `<application>` 안에 추가한다(설치 후 `.../native_geofence-*/README.md` 확인). `minSdkVersion`은 23 이상인지 `android/app/build.gradle(.kts)`에서 확인·상향.

- [ ] **Step 9: 분석 + 전체 테스트**

Run: `flutter analyze && flutter test`
Expected: analyze 무경고, 모든 유닛/위젯 테스트 PASS.

- [ ] **Step 10: 기기 수동 검증 (문서화)**

에뮬레이터(Android)에서 확인하고 결과를 커밋 메시지/워크로그에 기록:
1. 앱 실행 → 권한 프롬프트(위치·알림) → 목록 화면 표시.
2. 아이템 몇 개 추가.
3. 에뮬레이터 확장 컨트롤 → Location으로 시드 매장 좌표(예: 강남역 37.4979,127.0276) 주입 → ENTER 알림 노출 확인.
4. 알림 탭 → 앱 목록 화면 진입 확인.
5. 목록을 전부 완료/비운 뒤 재진입 → 알림 억제 확인.

- [ ] **Step 11: Commit**

```bash
git add lib/bootstrap.dart lib/app.dart lib/main.dart \
  lib/core/notifications/flutter_local_notification_service.dart \
  lib/core/geofence/native_geofence_service.dart \
  lib/features/stores/application/geofence_manager.dart \
  android/app/src/main/AndroidManifest.xml \
  test/bootstrap_test.dart
git commit -m "feat: wire bootstrap, notifications, and geofence ENTER callback"
```

---

### Task 13: 지오펜싱 비활성 배너 + 권한 온보딩 안내

**Files:**
- Create: `lib/features/shopping_list/presentation/geofencing_status_banner.dart`
- Modify: `lib/providers.dart` (지오펜싱 활성 상태 provider 추가)
- Modify: `lib/bootstrap.dart` (권한 결과를 상태로 노출)
- Modify: `lib/features/shopping_list/presentation/shopping_list_screen.dart` (배너 삽입)
- Test: `test/features/shopping_list/geofencing_status_banner_test.dart`

**Interfaces:**
- Consumes: Riverpod.
- Produces:
  - `final geofencingEnabledProvider = StateProvider<bool>((ref) => false);` (providers.dart) — 부트스트랩이 권한 granted면 true로 설정(main.dart에서 override 초기값 주입 또는 부트스트랩 후 컨테이너에 반영). 테스트에서는 override.
  - `class GeofencingStatusBanner extends ConsumerWidget` — `geofencingEnabledProvider`가 false면 `MaterialBanner` 스타일 안내(`"위치 알림이 꺼져 있어요. 매장 근처 알림을 받으려면 위치 권한을 항상 허용으로 설정하세요."`) 표시, true면 `SizedBox.shrink()`.

- [ ] **Step 1: Write the failing widget test**

`test/features/shopping_list/geofencing_status_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/presentation/geofencing_status_banner.dart';
import 'package:daijo/providers.dart';

Widget _host({required bool enabled}) => ProviderScope(
      overrides: [
        geofencingEnabledProvider.overrideWith((ref) => enabled),
      ],
      child: const MaterialApp(
        home: Scaffold(body: GeofencingStatusBanner()),
      ),
    );

void main() {
  testWidgets('shows warning when geofencing disabled', (tester) async {
    await tester.pumpWidget(_host(enabled: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('위치 권한'), findsOneWidget);
  });

  testWidgets('hides banner when geofencing enabled', (tester) async {
    await tester.pumpWidget(_host(enabled: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('위치 권한'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/shopping_list/geofencing_status_banner_test.dart`
Expected: FAIL — `geofencingEnabledProvider`/`GeofencingStatusBanner` 미정의.

- [ ] **Step 3: Add provider**

`lib/providers.dart`에 추가:

```dart
/// 지오펜싱(위치 권한 기반 알림) 활성 여부. main.dart 부트스트랩 결과로 override.
final geofencingEnabledProvider = StateProvider<bool>((ref) => false);
```

- [ ] **Step 4: Write the banner**

`lib/features/shopping_list/presentation/geofencing_status_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';

class GeofencingStatusBanner extends ConsumerWidget {
  const GeofencingStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(geofencingEnabledProvider);
    if (enabled) return const SizedBox.shrink();

    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: const Text(
        '위치 알림이 꺼져 있어요. 매장 근처 알림을 받으려면 '
        '위치 권한을 항상 허용으로 설정하세요.',
      ),
      actions: const [SizedBox.shrink()],
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/shopping_list/geofencing_status_banner_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: 화면에 배너 삽입 + 부트스트랩 상태 반영**

`shopping_list_screen.dart`의 `data:` 브랜치에서 목록 위에 배너를 얹는다(`Column`으로 감싸 `GeofencingStatusBanner()` + `Expanded(child: ListView(...))`). 빈 상태에서도 배너는 표시.

`main.dart`에서 부트스트랩의 권한 결과를 받아 `geofencingEnabledProvider`를 override 하거나, `ProviderScope` 생성 후 `container.read(geofencingEnabledProvider.notifier).state = granted`로 설정. 권장: `bootstrap`이 `Future<bool>`(granted 여부)를 반환하도록 바꾸고 그 값으로 `geofencingEnabledProvider.overrideWith((ref) => granted)`를 주입. bootstrap 반환 타입 변경 시 Task 12의 `bootstrap_test.dart` 기대값(반환 bool)도 함께 갱신.

- [ ] **Step 7: 분석 + 전체 테스트**

Run: `flutter analyze && flutter test`
Expected: analyze 무경고, 전체 PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/shopping_list/presentation/geofencing_status_banner.dart \
  lib/features/shopping_list/presentation/shopping_list_screen.dart \
  lib/providers.dart lib/bootstrap.dart lib/main.dart \
  test/features/shopping_list/geofencing_status_banner_test.dart \
  test/bootstrap_test.dart
git commit -m "feat: add geofencing-disabled status banner and onboarding hint"
```

---

## 완료 기준 (Definition of Done)

- 모든 유닛/위젯 테스트 통과, `flutter analyze` 무경고.
- 목록 CRUD + 완료 체크가 로컬에 영구 저장된다.
- 첫 실행 시 시드 매장이 DB에 적재된다(멱등).
- 앱 실행 시 현재 위치 기준 가까운 20개 매장에 150m 반경 지오펜스가 재등록된다.
- 매장 ENTER 시(목록에 미완료 아이템이 있을 때만) 요약 알림이 뜨고, 탭하면 목록 화면으로 진입한다(기기 수동 검증).
- 위치/알림 권한 거부 시 앱은 순수 목록 앱으로 동작하며 비활성 배너를 표시한다.

## 다음 사이클 (YAGNI — 본 계획 비범위)

매장 인앱 모드 · 스마트 입력 · 아카이브/재등록 · 백업/복원 · iOS. 각각 독립 스펙→계획→구현.
