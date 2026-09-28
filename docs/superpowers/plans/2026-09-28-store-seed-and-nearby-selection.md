# Store Seed & Nearby Selection (Slice A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 전국 다이소 매장 데이터를 앱에 1회 적재하고, 주어진 좌표에서 가까운 20개 매장 + 경계 반경을 계산하는 순수 로직을 구현한다(기기 불필요).

**Architecture:** Clean Architecture(feature-first). 매장 데이터는 Drift `Stores` 테이블에 버전 플래그 기반으로 1회 적재. 선별은 외부 의존 0의 순수 함수(`NearbySelector`). 위치 취득은 `LocationService` 인터페이스만 정의하고 실구현(geolocator)은 다음 슬라이스로 미룬다.

**Tech Stack:** Flutter 3.29.2(FVM), Dart ^3.7.2, Drift(SQLite), flutter_riverpod ^2.6.1. 명령은 PowerShell에서 `fvm flutter ...`.

**Spec:** `docs/superpowers/specs/2026-09-28-store-seed-and-nearby-selection-design.md`

## Global Constraints

- Clean Architecture 계층 분리: `presentation` / `domain` / `data`(+ `application`). 의존성은 domain을 향한다. domain은 프레임워크/외부 패키지 비의존.
- 상수: `kNearbyStoreCount = 20`, `kDefaultGeofenceRadiusMeters = 150.0`, `kEarthRadiusMeters = 6371000.0`.
- 시드 버전: `kStoresSeedVersion = 'daiso-2026-09-17'`, KV 키 `'stores_seed_version'`(Drift `app_settings` 재사용).
- `Store.id`는 String(JSON 원본 id 보존, native_geofence ID로 재사용).
- 모든 명령은 프로젝트 루트 `E:/Joonseo/dev_works/daijo`에서 PowerShell로 `fvm flutter ...`.
- 생성 코드(`*.g.dart`)는 커밋한다. `fvm flutter analyze` 무경고 유지.
- TDD: 실패 테스트 → 최소 구현 → 통과 → 커밋. 테스트는 in-memory Drift + 고정 좌표 픽스처.

---

### Task 1: `LatLng` 값 객체 + `LocationService` 인터페이스

**Files:**
- Create: `lib/core/location/location_service.dart`
- Test: `test/core/location/location_service_test.dart`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `class LatLng { const LatLng(this.latitude, this.longitude); final double latitude; final double longitude; }` (`==`/`hashCode` 포함)
  - `abstract class LocationService { Future<LatLng?> currentPosition(); }`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/core/location/location_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/location/location_service.dart';

void main() {
  test('LatLng equality and hashCode by value', () {
    expect(const LatLng(37.5, 127.0), const LatLng(37.5, 127.0));
    expect(const LatLng(37.5, 127.0).hashCode,
        const LatLng(37.5, 127.0).hashCode);
    expect(const LatLng(37.5, 127.0), isNot(const LatLng(37.5, 127.1)));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/core/location/location_service_test.dart`
Expected: FAIL — `location_service.dart` 없음 / `LatLng` 미정의.

- [ ] **Step 3: 최소 구현**

```dart
// lib/core/location/location_service.dart
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// 현재 위치 취득 인터페이스. 실구현(geolocator)은 다음 슬라이스에서 제공한다.
abstract class LocationService {
  /// 실패/권한 없음 시 null.
  Future<LatLng?> currentPosition();
}
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/core/location/location_service_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/core/location/location_service.dart test/core/location/location_service_test.dart
git commit -m "feat(location): LatLng value object + LocationService interface"
```

---

### Task 2: `Store` 엔티티

**Files:**
- Create: `lib/features/stores/domain/entities/store.dart`
- Test: `test/features/stores/domain/entities/store_test.dart`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `class Store { const Store({required this.id, required this.name, required this.latitude, required this.longitude, required this.radius}); final String id; final String name; final double latitude; final double longitude; final double radius; }` (`==`/`hashCode`)

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/stores/domain/entities/store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/stores/domain/entities/store.dart';

Store _store({String id = '1'}) => Store(
      id: id,
      name: '다이소 강남역점',
      latitude: 37.5,
      longitude: 127.0,
      radius: 150,
    );

void main() {
  test('Store equality by value', () {
    expect(_store(), _store());
    expect(_store().hashCode, _store().hashCode);
    expect(_store(id: '1'), isNot(_store(id: '2')));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/features/stores/domain/entities/store_test.dart`
Expected: FAIL — `store.dart` 없음.

- [ ] **Step 3: 최소 구현**

```dart
// lib/features/stores/domain/entities/store.dart
class Store {
  const Store({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is Store &&
      other.id == id &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude, radius);
}
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/features/stores/domain/entities/store_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/stores/domain/entities/store.dart test/features/stores/domain/entities/store_test.dart
git commit -m "feat(stores): Store entity"
```

---

### Task 3: Haversine 거리 함수

**Files:**
- Create: `lib/features/stores/application/nearby_selector.dart` (이 태스크에선 거리 함수만)
- Test: `test/features/stores/application/haversine_test.dart`

**Interfaces:**
- Consumes: `LatLng` (Task 1)
- Produces: `double haversineMeters(LatLng a, LatLng b)` — 지구 반경 `kEarthRadiusMeters` 사용한 대권거리(미터).

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/stores/application/haversine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/features/stores/application/nearby_selector.dart';

void main() {
  test('1 degree of latitude at equator ~= 111194.9 m', () {
    final d = haversineMeters(const LatLng(0, 0), const LatLng(1, 0));
    expect(d, closeTo(111194.9, 1.0));
  });

  test('same point is zero distance', () {
    expect(haversineMeters(const LatLng(37.5, 127.0), const LatLng(37.5, 127.0)),
        closeTo(0, 1e-6));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/features/stores/application/haversine_test.dart`
Expected: FAIL — `nearby_selector.dart` 없음 / `haversineMeters` 미정의.

- [ ] **Step 3: 최소 구현**

```dart
// lib/features/stores/application/nearby_selector.dart
import 'dart:math' as math;

import '../../../core/location/location_service.dart';

const double kEarthRadiusMeters = 6371000.0;

double haversineMeters(LatLng a, LatLng b) {
  final lat1 = _toRad(a.latitude);
  final lat2 = _toRad(b.latitude);
  final dLat = _toRad(b.latitude - a.latitude);
  final dLng = _toRad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * kEarthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
}

double _toRad(double deg) => deg * math.pi / 180.0;
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/features/stores/application/haversine_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/stores/application/nearby_selector.dart test/features/stores/application/haversine_test.dart
git commit -m "feat(stores): haversine distance helper"
```

---

### Task 4: `GeofenceSelection` + `NearbySelector.select`

**Files:**
- Create: `lib/features/stores/domain/entities/geofence_selection.dart`
- Modify: `lib/features/stores/application/nearby_selector.dart` (`NearbySelector` 추가)
- Test: `test/features/stores/application/nearby_selector_test.dart`

**Interfaces:**
- Consumes: `LatLng` (Task 1), `Store` (Task 2), `haversineMeters` (Task 3)
- Produces:
  - `class GeofenceSelection { const GeofenceSelection({required this.center, required this.stores, required this.boundaryRadiusMeters}); const GeofenceSelection.empty(); final LatLng center; final List<Store> stores; final double boundaryRadiusMeters; }`
  - `abstract final class NearbySelector { static GeofenceSelection select(LatLng center, List<Store> stores, {int n = kNearbyStoreCount}); }`
  - `const int kNearbyStoreCount = 20;`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/stores/application/nearby_selector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/features/stores/application/nearby_selector.dart';
import 'package:daijo/features/stores/domain/entities/store.dart';

Store _s(String id, double lat, double lng) =>
    Store(id: id, name: 'store-$id', latitude: lat, longitude: lng, radius: 150);

void main() {
  const center = LatLng(0, 0);

  test('sorts by distance and caps at n', () {
    final stores = [
      _s('far', 0, 3),
      _s('near', 0, 1),
      _s('mid', 0, 2),
    ];
    final result = NearbySelector.select(center, stores, n: 2);
    expect(result.stores.map((s) => s.id).toList(), ['near', 'mid']);
  });

  test('boundary radius equals distance to farthest selected store', () {
    final stores = [_s('a', 0, 1), _s('b', 0, 2)];
    final result = NearbySelector.select(center, stores, n: 2);
    expect(result.boundaryRadiusMeters,
        closeTo(haversineMeters(center, const LatLng(0, 2)), 1e-6));
  });

  test('ties broken by id ascending', () {
    final stores = [_s('b', 0, 1), _s('a', 0, 1)];
    final result = NearbySelector.select(center, stores, n: 1);
    expect(result.stores.single.id, 'a');
  });

  test('fewer stores than n selects all', () {
    final result = NearbySelector.select(center, [_s('a', 0, 1)], n: 20);
    expect(result.stores.length, 1);
    expect(result.boundaryRadiusMeters,
        closeTo(haversineMeters(center, const LatLng(0, 1)), 1e-6));
  });

  test('empty store list yields empty selection with zero radius', () {
    final result = NearbySelector.select(center, [], n: 20);
    expect(result.stores, isEmpty);
    expect(result.boundaryRadiusMeters, 0);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/features/stores/application/nearby_selector_test.dart`
Expected: FAIL — `GeofenceSelection`/`NearbySelector` 미정의.

- [ ] **Step 3: 최소 구현**

```dart
// lib/features/stores/domain/entities/geofence_selection.dart
import '../../../../core/location/location_service.dart';
import 'store.dart';

class GeofenceSelection {
  const GeofenceSelection({
    required this.center,
    required this.stores,
    required this.boundaryRadiusMeters,
  });

  const GeofenceSelection.empty()
      : center = const LatLng(0, 0),
        stores = const [],
        boundaryRadiusMeters = 0;

  final LatLng center;
  final List<Store> stores;
  final double boundaryRadiusMeters;
}
```

`nearby_selector.dart`에 추가(파일 상단 import + 상수 + 클래스):

```dart
// lib/features/stores/application/nearby_selector.dart 에 추가
import '../domain/entities/geofence_selection.dart';
import '../domain/entities/store.dart';

const int kNearbyStoreCount = 20;

abstract final class NearbySelector {
  static GeofenceSelection select(
    LatLng center,
    List<Store> stores, {
    int n = kNearbyStoreCount,
  }) {
    if (stores.isEmpty) {
      return GeofenceSelection(center: center, stores: const [], boundaryRadiusMeters: 0);
    }
    final withDistance = stores
        .map((s) => (
              store: s,
              distance: haversineMeters(center, LatLng(s.latitude, s.longitude)),
            ))
        .toList()
      ..sort((a, b) {
        final byDistance = a.distance.compareTo(b.distance);
        return byDistance != 0 ? byDistance : a.store.id.compareTo(b.store.id);
      });
    final selected = withDistance.take(n).toList();
    return GeofenceSelection(
      center: center,
      stores: selected.map((e) => e.store).toList(),
      boundaryRadiusMeters: selected.last.distance,
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/features/stores/application/nearby_selector_test.dart`
Expected: PASS(5 케이스).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/stores/domain/entities/geofence_selection.dart lib/features/stores/application/nearby_selector.dart test/features/stores/application/nearby_selector_test.dart
git commit -m "feat(stores): GeofenceSelection + NearbySelector (nearest N + boundary radius)"
```

---

### Task 5: `Stores` Drift 테이블 + schemaVersion 3 마이그레이션

**Files:**
- Modify: `lib/core/database/app_database.dart` (테이블 추가, schemaVersion 3, onUpgrade 분기)
- Modify: `lib/core/database/app_database.g.dart` (생성 — build_runner)
- Test: `test/core/database/stores_table_test.dart`

**Interfaces:**
- Consumes: (없음)
- Produces: Drift 생성 API `db.stores`(테이블), `StoreRow` 데이터 클래스(`id`,`name`,`latitude`,`longitude`,`radius`), `StoresCompanion`. `db.schemaVersion == 3`.

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/core/database/stores_table_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';

void main() {
  test('stores table stores and reads a row; schemaVersion is 3', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 3);

    await db.into(db.stores).insert(const StoresCompanion(
          id: Value('42'),
          name: Value('다이소 강남역점'),
          latitude: Value(37.5),
          longitude: Value(127.0),
          radius: Value(150.0),
        ));
    final rows = await db.select(db.stores).get();
    expect(rows.single.id, '42');
    expect(rows.single.radius, 150.0);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/core/database/stores_table_test.dart`
Expected: FAIL — `db.stores`/`StoresCompanion` 미생성(컴파일 에러).

- [ ] **Step 3: 테이블 정의 + 마이그레이션 수정**

`lib/core/database/app_database.dart`:

```dart
@DataClassName('StoreRow')
class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get radius => real()();

  @override
  Set<Column> get primaryKey => {id};
}
```

`@DriftDatabase(tables: [...])`에 `Stores` 추가:

```dart
@DriftDatabase(tables: [ShoppingItems, AppSettings, Stores])
```

`schemaVersion`을 3으로, `onUpgrade`에 분기 추가:

```dart
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(appSettings);
          }
          if (from < 3) {
            await m.createTable(stores);
          }
        },
      );
```

- [ ] **Step 4: 생성 코드 재생성**

Run: `fvm dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` 갱신(에러 없음).

- [ ] **Step 5: 통과 확인**

Run: `fvm flutter test test/core/database/stores_table_test.dart`
Expected: PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/core/database/app_database.dart lib/core/database/app_database.g.dart test/core/database/stores_table_test.dart
git commit -m "feat(db): add Stores table, schemaVersion 3 migration"
```

---

### Task 6: `StoreRepository` 인터페이스 + 매퍼 + 데이터소스 + 구현

**Files:**
- Create: `lib/features/stores/domain/repositories/store_repository.dart`
- Create: `lib/features/stores/data/mappers/store_mapper.dart`
- Create: `lib/features/stores/data/datasources/store_local_datasource.dart`
- Create: `lib/features/stores/data/repositories/store_repository_impl.dart`
- Test: `test/features/stores/data/store_repository_impl_test.dart`

**Interfaces:**
- Consumes: `Store` (Task 2), `AppDatabase`/`StoreRow`/`StoresCompanion` (Task 5)
- Produces:
  - `abstract class StoreRepository { Future<List<Store>> getAll(); Future<void> replaceAll(List<Store> stores); Future<void> clear(); }`
  - `Store storeFromRow(StoreRow row)` / `StoresCompanion storeToCompanion(Store s)` (store_mapper.dart)
  - `class StoreLocalDataSource { StoreLocalDataSource(AppDatabase db); Future<List<StoreRow>> getAll(); Future<void> replaceAll(List<Store> stores); Future<void> clear(); }`
  - `class StoreRepositoryImpl implements StoreRepository { StoreRepositoryImpl(StoreLocalDataSource ds); }`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/stores/data/store_repository_impl_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/stores/data/datasources/store_local_datasource.dart';
import 'package:daijo/features/stores/data/repositories/store_repository_impl.dart';
import 'package:daijo/features/stores/domain/entities/store.dart';

Store _s(String id) =>
    Store(id: id, name: 'store-$id', latitude: 37.5, longitude: 127.0, radius: 150);

void main() {
  late AppDatabase db;
  late StoreRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StoreRepositoryImpl(StoreLocalDataSource(db));
  });
  tearDown(() => db.close());

  test('replaceAll then getAll round-trips stores', () async {
    await repo.replaceAll([_s('1'), _s('2')]);
    final all = await repo.getAll();
    expect(all.map((s) => s.id).toSet(), {'1', '2'});
  });

  test('replaceAll clears previous rows first', () async {
    await repo.replaceAll([_s('1'), _s('2')]);
    await repo.replaceAll([_s('3')]);
    final all = await repo.getAll();
    expect(all.map((s) => s.id).toList(), ['3']);
  });

  test('clear empties the table', () async {
    await repo.replaceAll([_s('1')]);
    await repo.clear();
    expect(await repo.getAll(), isEmpty);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/features/stores/data/store_repository_impl_test.dart`
Expected: FAIL — 클래스들 미정의.

- [ ] **Step 3: 최소 구현**

```dart
// lib/features/stores/domain/repositories/store_repository.dart
import '../entities/store.dart';

abstract class StoreRepository {
  Future<List<Store>> getAll();
  Future<void> replaceAll(List<Store> stores);
  Future<void> clear();
}
```

```dart
// lib/features/stores/data/mappers/store_mapper.dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/store.dart';

Store storeFromRow(StoreRow row) => Store(
      id: row.id,
      name: row.name,
      latitude: row.latitude,
      longitude: row.longitude,
      radius: row.radius,
    );

StoresCompanion storeToCompanion(Store s) => StoresCompanion(
      id: Value(s.id),
      name: Value(s.name),
      latitude: Value(s.latitude),
      longitude: Value(s.longitude),
      radius: Value(s.radius),
    );
```

```dart
// lib/features/stores/data/datasources/store_local_datasource.dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/store.dart';
import '../mappers/store_mapper.dart';

class StoreLocalDataSource {
  StoreLocalDataSource(this._db);

  final AppDatabase _db;

  Future<List<StoreRow>> getAll() => _db.select(_db.stores).get();

  Future<void> replaceAll(List<Store> stores) {
    return _db.transaction(() async {
      await _db.delete(_db.stores).go();
      await _db.batch((b) {
        b.insertAll(_db.stores, stores.map(storeToCompanion).toList());
      });
    });
  }

  Future<void> clear() => _db.delete(_db.stores).go();
}
```

```dart
// lib/features/stores/data/repositories/store_repository_impl.dart
import '../../domain/entities/store.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_local_datasource.dart';
import '../mappers/store_mapper.dart';

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl(this._ds);

  final StoreLocalDataSource _ds;

  @override
  Future<List<Store>> getAll() async =>
      (await _ds.getAll()).map(storeFromRow).toList();

  @override
  Future<void> replaceAll(List<Store> stores) => _ds.replaceAll(stores);

  @override
  Future<void> clear() => _ds.clear();
}
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/features/stores/data/store_repository_impl_test.dart`
Expected: PASS(3 케이스).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/stores/domain/repositories/store_repository.dart lib/features/stores/data/ test/features/stores/data/store_repository_impl_test.dart
git commit -m "feat(stores): StoreRepository + Drift datasource/impl + mapper"
```

---

### Task 7: `StoreSeedLoader` (에셋 JSON 파싱)

**Files:**
- Create: `lib/features/stores/data/datasources/store_seed_loader.dart`
- Test: `test/features/stores/data/store_seed_loader_test.dart`

**Interfaces:**
- Consumes: `Store` (Task 2)
- Produces:
  - `const double kDefaultGeofenceRadiusMeters = 150.0;`
  - `class StoreSeedLoader { StoreSeedLoader(AssetBundle bundle, {String assetPath = 'assets/data/daiso_stores.json'}); Future<List<Store>> load(); }` — JSON 배열을 `Store`로 매핑(`radius`=150 주입, `id`는 String 보존).

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/stores/data/store_seed_loader_test.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/stores/data/datasources/store_seed_loader.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._data);
  final String _data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(_data);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

void main() {
  test('parses JSON array into stores with default radius and string id', () async {
    const json = '''
    [
      {"id":"12638299","name":"다이소 강남역2호점","address":"서울","latitude":37.498793,"longitude":127.028934,"phone":"1522-4400"}
    ]''';
    final loader = StoreSeedLoader(_FakeBundle(json));
    final stores = await loader.load();
    expect(stores.single.id, '12638299');
    expect(stores.single.name, '다이소 강남역2호점');
    expect(stores.single.latitude, 37.498793);
    expect(stores.single.radius, 150.0);
  });

  test('throws on malformed JSON', () async {
    final loader = StoreSeedLoader(_FakeBundle('not json'));
    expect(loader.load(), throwsA(anything));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/features/stores/data/store_seed_loader_test.dart`
Expected: FAIL — `StoreSeedLoader` 미정의.

- [ ] **Step 3: 최소 구현**

```dart
// lib/features/stores/data/datasources/store_seed_loader.dart
import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

import '../../domain/entities/store.dart';

const double kDefaultGeofenceRadiusMeters = 150.0;

class StoreSeedLoader {
  StoreSeedLoader(this._bundle,
      {this.assetPath = 'assets/data/daiso_stores.json'});

  final AssetBundle _bundle;
  final String assetPath;

  Future<List<Store>> load() async {
    final raw = await _bundle.loadString(assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Store _fromJson(Map<String, dynamic> j) => Store(
        id: j['id'].toString(),
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radius: kDefaultGeofenceRadiusMeters,
      );
}
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/features/stores/data/store_seed_loader_test.dart`
Expected: PASS(2 케이스).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/stores/data/datasources/store_seed_loader.dart test/features/stores/data/store_seed_loader_test.dart
git commit -m "feat(stores): StoreSeedLoader parses asset JSON into Store list"
```

---

### Task 8: `StoreSeeder` (버전 플래그 기반 멱등 적재)

**Files:**
- Create: `lib/features/stores/application/store_seeder.dart`
- Test: `test/features/stores/application/store_seeder_test.dart`

**Interfaces:**
- Consumes: `StoreSeedLoader` (Task 7), `StoreRepository` (Task 6), `AppDatabase.getSetting/setSetting` (기존)
- Produces:
  - `const String kStoresSeedVersion = 'daiso-2026-09-17';`
  - `class StoreSeeder { StoreSeeder({required StoreSeedLoader loader, required StoreRepository repository, required AppDatabase db}); Future<void> ensureSeeded(); }`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/stores/application/store_seeder_test.dart
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/stores/application/store_seeder.dart';
import 'package:daijo/features/stores/data/datasources/store_local_datasource.dart';
import 'package:daijo/features/stores/data/datasources/store_seed_loader.dart';
import 'package:daijo/features/stores/data/repositories/store_repository_impl.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.data);
  String data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(data);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

String _json(List<String> ids) => jsonEncode([
      for (final id in ids)
        {'id': id, 'name': 's$id', 'latitude': 37.5, 'longitude': 127.0}
    ]);

void main() {
  late AppDatabase db;
  late StoreRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StoreRepositoryImpl(StoreLocalDataSource(db));
  });
  tearDown(() => db.close());

  StoreSeeder seeder(_FakeBundle bundle) => StoreSeeder(
        loader: StoreSeedLoader(bundle),
        repository: repo,
        db: db,
      );

  test('first run loads stores and records version', () async {
    await seeder(_FakeBundle(_json(['1', '2']))).ensureSeeded();
    expect((await repo.getAll()).length, 2);
    expect(await db.getSetting('stores_seed_version'), kStoresSeedVersion);
  });

  test('second run with same version skips reload', () async {
    final bundle = _FakeBundle(_json(['1', '2']));
    await seeder(bundle).ensureSeeded();
    bundle.data = _json(['9']); // changed asset, but version unchanged
    await seeder(bundle).ensureSeeded();
    expect((await repo.getAll()).map((s) => s.id).toSet(), {'1', '2'});
  });

  test('malformed JSON degrades: no crash, no version recorded', () async {
    await seeder(_FakeBundle('not json')).ensureSeeded();
    expect(await repo.getAll(), isEmpty);
    expect(await db.getSetting('stores_seed_version'), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/features/stores/application/store_seeder_test.dart`
Expected: FAIL — `StoreSeeder` 미정의.

- [ ] **Step 3: 최소 구현**

```dart
// lib/features/stores/application/store_seeder.dart
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../data/datasources/store_seed_loader.dart';
import '../domain/repositories/store_repository.dart';

const String kStoresSeedVersion = 'daiso-2026-09-17';
const String _versionKey = 'stores_seed_version';

class StoreSeeder {
  StoreSeeder({
    required StoreSeedLoader loader,
    required StoreRepository repository,
    required AppDatabase db,
  })  : _loader = loader,
        _repo = repository,
        _db = db;

  final StoreSeedLoader _loader;
  final StoreRepository _repo;
  final AppDatabase _db;

  Future<void> ensureSeeded() async {
    final current = await _db.getSetting(_versionKey);
    if (current == kStoresSeedVersion) return;
    try {
      final stores = await _loader.load();
      await _repo.replaceAll(stores);
      await _db.setSetting(_versionKey, kStoresSeedVersion);
    } catch (e) {
      debugPrint('[StoreSeeder] seed load failed, keeping existing data: $e');
    }
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/features/stores/application/store_seeder_test.dart`
Expected: PASS(3 케이스).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/stores/application/store_seeder.dart test/features/stores/application/store_seeder_test.dart
git commit -m "feat(stores): StoreSeeder version-flagged idempotent load"
```

---

### Task 9: 프로바이더 + `nearbySelectionProvider`

**Files:**
- Create: `lib/features/stores/presentation/stores_providers.dart`
- Test: `test/features/stores/presentation/stores_providers_test.dart`

**Interfaces:**
- Consumes: `StoreRepositoryImpl`/`StoreLocalDataSource` (Task 6), `StoreSeedLoader` (Task 7), `StoreSeeder` (Task 8), `NearbySelector` (Task 4), `LocationService`/`LatLng` (Task 1), `appDatabaseProvider` (기존, `features/shopping_list/presentation/shopping_list_providers.dart`)
- Produces:
  - `storeRepositoryProvider` → `StoreRepository`
  - `storeSeederProvider` → `StoreSeeder`
  - `locationServiceProvider` → `LocationService` (기본은 override 필요 스텁)
  - `nearbySelectionProvider` → `FutureProvider<GeofenceSelection>`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/stores/presentation/stores_providers_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:daijo/features/stores/domain/entities/store.dart';
import 'package:daijo/features/stores/presentation/stores_providers.dart';

class _FakeLocation implements LocationService {
  _FakeLocation(this._pos);
  final LatLng? _pos;
  @override
  Future<LatLng?> currentPosition() async => _pos;
}

Store _s(String id, double lng) =>
    Store(id: id, name: 's$id', latitude: 0, longitude: lng, radius: 150);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer containerWith(LocationService loc) => ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          locationServiceProvider.overrideWithValue(loc),
        ],
      );

  test('nearbySelectionProvider selects nearest stores at current position',
      () async {
    final c = containerWith(_FakeLocation(const LatLng(0, 0)));
    addTearDown(c.dispose);
    await c.read(storeRepositoryProvider).replaceAll([_s('far', 3), _s('near', 1)]);

    final selection = await c.read(nearbySelectionProvider.future);
    expect(selection.stores.first.id, 'near');
  });

  test('nearbySelectionProvider returns empty when location is null', () async {
    final c = containerWith(_FakeLocation(null));
    addTearDown(c.dispose);
    await c.read(storeRepositoryProvider).replaceAll([_s('a', 1)]);

    final selection = await c.read(nearbySelectionProvider.future);
    expect(selection.stores, isEmpty);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `fvm flutter test test/features/stores/presentation/stores_providers_test.dart`
Expected: FAIL — 프로바이더 미정의.

- [ ] **Step 3: 최소 구현**

```dart
// lib/features/stores/presentation/stores_providers.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../shopping_list/presentation/shopping_list_providers.dart';
import '../application/nearby_selector.dart';
import '../application/store_seeder.dart';
import '../data/datasources/store_local_datasource.dart';
import '../data/datasources/store_seed_loader.dart';
import '../data/repositories/store_repository_impl.dart';
import '../domain/entities/geofence_selection.dart';
import '../domain/repositories/store_repository.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return StoreRepositoryImpl(StoreLocalDataSource(db));
});

final storeSeederProvider = Provider<StoreSeeder>((ref) {
  return StoreSeeder(
    loader: StoreSeedLoader(rootBundle),
    repository: ref.watch(storeRepositoryProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => throw UnimplementedError(
    'locationServiceProvider must be overridden',
  ),
);

final nearbySelectionProvider = FutureProvider<GeofenceSelection>((ref) async {
  final position = await ref.watch(locationServiceProvider).currentPosition();
  if (position == null) return const GeofenceSelection.empty();
  final stores = await ref.watch(storeRepositoryProvider).getAll();
  return NearbySelector.select(position, stores);
});
```

- [ ] **Step 4: 통과 확인**

Run: `fvm flutter test test/features/stores/presentation/stores_providers_test.dart`
Expected: PASS(2 케이스).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/stores/presentation/stores_providers.dart test/features/stores/presentation/stores_providers_test.dart
git commit -m "feat(stores): providers + nearbySelectionProvider"
```

---

### Task 10: 부팅 배선(시드 적재) + 전체 검증

**Files:**
- Modify: `lib/main.dart` (부팅 시 `StoreSeeder.ensureSeeded()` 1회 호출)
- Test: (신규 없음 — 로직은 Task 8에서 검증. 전체 스위트 + analyze로 회귀 확인)

**Interfaces:**
- Consumes: `storeSeederProvider` (Task 9), `appDatabaseProvider`/`permissionServiceProvider` (기존)

- [ ] **Step 1: main에 시드 적재 배선**

`lib/main.dart`의 `main()`에서 DB 생성 직후, `runApp` 전에 시드를 적재한다. 시더는 `ProviderContainer`로 구성해 재사용한다:

```dart
// lib/main.dart (import 추가)
import 'features/stores/application/store_seeder.dart';
import 'features/stores/data/datasources/store_local_datasource.dart';
import 'features/stores/data/datasources/store_seed_loader.dart';
import 'features/stores/data/repositories/store_repository_impl.dart';
import 'package:flutter/services.dart' show rootBundle;
```

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();

  // 매장 시드 1회 적재(버전 플래그 기반). 실패해도 앱은 계속 동작.
  await StoreSeeder(
    loader: StoreSeedLoader(rootBundle),
    repository: StoreRepositoryImpl(StoreLocalDataSource(db)),
    db: db,
  ).ensureSeeded();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        permissionServiceProvider.overrideWithValue(
          const PermissionHandlerService(),
        ),
      ],
      child: const DaijoApp(),
    ),
  );
}
```

- [ ] **Step 2: 전체 테스트**

Run: `fvm flutter test`
Expected: 전체 PASS(기존 64 + 신규 케이스).

- [ ] **Step 3: analyze**

Run: `fvm flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: (선택) 디바이스 로그 스모크**

Run: `fvm flutter run` 후 로그에서 최초 실행 시 시드 적재가 1회 일어나고 재실행 시 skip 되는지 확인(수동, 비차단). `daiso_stores.json` 좌표 스팟체크(강남역점 등 2~3개).

- [ ] **Step 5: 커밋**

```bash
git add lib/main.dart
git commit -m "feat(app): seed stores on boot via StoreSeeder"
```

---

## Self-Review

**Spec coverage:**
- 시드 적재(버전 플래그) → Task 5(테이블)·7(로더)·8(시더)·10(배선). ✔
- 가까운 20개 + 경계 반경(Haversine, tie-break, 엣지) → Task 3·4. ✔
- `Store` 필드(id String, radius 150) → Task 2·7. ✔
- `LocationService` 인터페이스만 → Task 1·9(스텁 provider). ✔
- schemaVersion 3 마이그레이션 → Task 5. ✔
- 데이터 흐름(위치→선별) → Task 9 `nearbySelectionProvider`. ✔
- 오류 처리(위치 null, 파싱 실패, 적재 실패) → Task 8·9 테스트. ✔
- 테스트 전략 6항목 → Task 1~9 테스트로 커버. ✔

**Placeholder scan:** 모든 step에 실제 코드/명령 포함, TBD/TODO 없음. ✔

**Type consistency:** `LatLng`(Task1)·`Store`(Task2)·`GeofenceSelection`/`NearbySelector.select`(Task4)·`StoreRepository`(Task6)·`StoreSeedLoader.load`(Task7)·`StoreSeeder.ensureSeeded`(Task8)·providers(Task9) 시그니처가 태스크 간 일치. `kNearbyStoreCount`/`kDefaultGeofenceRadiusMeters`/`kEarthRadiusMeters`/`kStoresSeedVersion` 상수명 일관. ✔
