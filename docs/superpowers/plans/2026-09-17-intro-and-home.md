# 다이저 인트로 + 홈 화면 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 다이저 앱의 첫 화면 슬라이스 — 인트로(스플래시) 페이지와 쇼핑 목록 홈 페이지(로컬 영구저장 CRUD) — 를 Clean Architecture로 구현한다.

**Architecture:** Clean Architecture 3계층(presentation / domain / data), 의존은 항상 domain 안쪽으로. domain은 순수 Dart(프레임워크·패키지 미의존). data는 Drift로 영속화하고 매퍼로 도메인 엔티티에 매핑. presentation은 Riverpod으로 상태를 관리하며 domain 인터페이스만 알고 구현체는 DI로 주입받는다.

**Tech Stack:** Flutter 3.29.2 (FVM), Riverpod 2.x(`flutter_riverpod ^2.6.1`), Drift(SQLite) + build_runner, package_info_plus.

**Spec:** `docs/brainstorming/2026-09-17-intro-and-home.md` (청사진: `docs/design/2026-09-17-intro-and-home.html`)

## Global Constraints

- 앱 표시 이름 **다이저**. 패키지명 `daijo` (imports: `package:daijo/...`).
- **모든 명령은 PowerShell에서 `fvm flutter ...` / `fvm dart ...`로 프로젝트 루트 `E:/Joonseo/dev_works/daijo`에서 실행.** bare flutter/dart 금지.
- Clean Architecture 의존 방향: presentation → domain ← data. **domain 계층 파일은 flutter/drift/riverpod 등 어떤 패키지도 import 하지 않는다.**
- 상태관리 Riverpod 2.x, 로컬 DB Drift(테스트는 in-memory). 생성 코드(`*.g.dart`) 커밋.
- 정렬 규칙: 미완료 먼저, 각 그룹 등록순(오름차순). **DB 쿼리에서 처리**(`ORDER BY is_done ASC, created_at ASC`).
- 수량 기본 1, 최소 1. 빈 이름(trim 후 공백) 추가/수정은 no-op.
- 완료 항목은 회색·취소선 + 목록 하단(“완료” 구분선 아래).
- 삭제는 스와이프 즉시 삭제(Undo 없음).
- 버전 표시는 `package_info_plus`의 pubspec 버전으로 `v<version>` 형식(예: `v1.0.0`).
- 인트로는 매 실행 스플래시, 약 2초 후 홈으로 자동 전환. **이 슬라이스에서 권한 요청·지오펜싱은 없다.**
- `fvm flutter analyze`는 각 태스크 커밋 전 무경고.
- Drift 데이터 클래스 이름 충돌 방지: 테이블에 `@DataClassName('ShoppingItemRow')` 지정 → 생성 클래스는 `ShoppingItemRow`, 도메인 엔티티는 `ShoppingItem`.

---

## File Structure

```
lib/
  main.dart                        ProviderScope + 실제 DB 오픈 + runApp
  app.dart                         MaterialApp(테마, home: IntroPage)
  core/
    database/
      app_database.dart            Drift DB + ShoppingItems 테이블
      app_database.g.dart          (생성)
  features/
    intro/
      presentation/
        intro_page.dart            스플래시 UI + 타이머 → 홈 전환
    shopping_list/
      domain/
        entities/shopping_item.dart            순수 Dart 엔티티
        repositories/shopping_item_repository.dart  추상 인터페이스
      data/
        mappers/shopping_item_mapper.dart      ShoppingItemRow → ShoppingItem
        datasources/shopping_item_local_datasource.dart  Drift 연산
        repositories/shopping_item_repository_impl.dart   인터페이스 구현
      presentation/
        shopping_list_providers.dart           provider + 컨트롤러
        app_version_provider.dart              버전 FutureProvider
        widgets/add_item_field.dart            상단 입력줄(콜백)
        widgets/shopping_item_tile.dart        항목 타일(콜백)
        home_page.dart                         홈 조립
test/
  features/shopping_list/domain/shopping_item_test.dart
  core/database/app_database_test.dart
  features/shopping_list/data/shopping_item_mapper_test.dart
  features/shopping_list/data/shopping_item_local_datasource_test.dart
  features/shopping_list/data/shopping_item_repository_impl_test.dart
  features/shopping_list/presentation/shopping_list_controller_test.dart
  features/shopping_list/presentation/app_version_provider_test.dart
  features/shopping_list/presentation/widgets/add_item_field_test.dart
  features/shopping_list/presentation/widgets/shopping_item_tile_test.dart
  features/shopping_list/presentation/home_page_test.dart
  features/intro/presentation/intro_page_test.dart
```

---

### Task 1: 도메인 엔티티 + repository 인터페이스 (~15분)

**Files:**
- Create: `lib/features/shopping_list/domain/entities/shopping_item.dart`
- Create: `lib/features/shopping_list/domain/repositories/shopping_item_repository.dart`
- Test: `test/features/shopping_list/domain/shopping_item_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class ShoppingItem` — 생성자 `ShoppingItem({required int id, required String name, required int quantity, required bool isDone, required DateTime createdAt})`, 값 동등성(`==`/`hashCode`), `copyWith`.
  - `abstract interface class ShoppingItemRepository` — `Stream<List<ShoppingItem>> watchAll()`, `Future<void> add(String name)`, `Future<void> rename(int id, String name)`, `Future<void> setQuantity(int id, int quantity)`, `Future<void> setDone(int id, bool isDone)`, `Future<void> delete(int id)`.
- **domain 규칙: 이 두 파일은 어떤 외부 패키지도 import 하지 않는다.**

- [ ] **Step 1: Write the failing test**

`test/features/shopping_list/domain/shopping_item_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/domain/entities/shopping_item.dart';

void main() {
  final createdAt = DateTime(2026, 9, 17);

  ShoppingItem base() => ShoppingItem(
        id: 1,
        name: '수세미',
        quantity: 2,
        isDone: false,
        createdAt: createdAt,
      );

  test('value equality holds for identical field values', () {
    expect(base(), equals(base()));
    expect(base().hashCode, base().hashCode);
  });

  test('copyWith overrides only the given fields', () {
    final done = base().copyWith(isDone: true, quantity: 5);
    expect(done.isDone, isTrue);
    expect(done.quantity, 5);
    expect(done.name, '수세미');
    expect(done.id, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/shopping_list/domain/shopping_item_test.dart`
Expected: FAIL — `ShoppingItem` 미정의(컴파일 실패).

- [ ] **Step 3: Write the entity**

`lib/features/shopping_list/domain/entities/shopping_item.dart`:

```dart
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.isDone,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int quantity;
  final bool isDone;
  final DateTime createdAt;

  ShoppingItem copyWith({
    int? id,
    String? name,
    int? quantity,
    bool? isDone,
    DateTime? createdAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShoppingItem &&
      other.id == id &&
      other.name == name &&
      other.quantity == quantity &&
      other.isDone == isDone &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, quantity, isDone, createdAt);
}
```

- [ ] **Step 4: Write the repository interface**

`lib/features/shopping_list/domain/repositories/shopping_item_repository.dart`:

```dart
import '../entities/shopping_item.dart';

abstract interface class ShoppingItemRepository {
  /// 미완료(등록순) → 완료(등록순) 정렬된 전체 목록 스트림.
  Stream<List<ShoppingItem>> watchAll();

  /// 새 항목 추가. 이름 trim 후 공백이면 무시. 수량 기본 1.
  Future<void> add(String name);

  /// 이름 변경. trim 후 공백이면 무시.
  Future<void> rename(int id, String name);

  /// 수량 변경. 1 미만이면 1로 보정.
  Future<void> setQuantity(int id, int quantity);

  Future<void> setDone(int id, bool isDone);

  Future<void> delete(int id);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `fvm flutter test test/features/shopping_list/domain/shopping_item_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/features/shopping_list/domain test/features/shopping_list/domain
git commit -m "feat(domain): add ShoppingItem entity and repository interface"
```

---

### Task 2: Drift DB + ShoppingItems 테이블 (~25분)

**Files:**
- Create: `lib/core/database/app_database.dart`
- Create (생성): `lib/core/database/app_database.g.dart`
- Test: `test/core/database/app_database_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - 테이블 `ShoppingItems` (`@DataClassName('ShoppingItemRow')`), 컬럼: `id` int autoIncrement PK, `name` text(1~100), `quantity` int default 1, `isDone` bool default false, `createdAt` datetime.
  - Drift 생성 행 클래스 `ShoppingItemRow`, companion `ShoppingItemsCompanion`.
  - `class AppDatabase extends _$AppDatabase` — `AppDatabase(QueryExecutor)`, `AppDatabase.forTesting(QueryExecutor)`, `schemaVersion == 1`, 접근자 `shoppingItems`.

- [ ] **Step 1: Write the failing test**

`test/core/database/app_database_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema version is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('shopping_items table starts empty', () async {
    expect(await db.select(db.shoppingItems).get(), isEmpty);
  });

  test('insert then read returns the row with defaults', () async {
    await db.into(db.shoppingItems).insert(
          ShoppingItemsCompanion.insert(name: '건전지', createdAt: DateTime(2026)),
        );
    final row = (await db.select(db.shoppingItems).get()).single;
    expect(row.name, '건전지');
    expect(row.quantity, 1);
    expect(row.isDone, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/core/database/app_database_test.dart`
Expected: FAIL — `AppDatabase` 미정의.

- [ ] **Step 3: Write the database definition**

`lib/core/database/app_database.dart`:

```dart
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DataClassName('ShoppingItemRow')
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [ShoppingItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 4: 코드 생성**

Run: `fvm dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/core/database/app_database.g.dart` 생성(오류 없음). 생성 행 클래스 이름이 `ShoppingItemRow`인지 확인.

- [ ] **Step 5: Run test to verify it passes**

Run: `fvm flutter test test/core/database/app_database_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/core/database test/core/database
git commit -m "feat(data): add Drift AppDatabase with shopping_items table"
```

---

### Task 3: 매퍼 (ShoppingItemRow → ShoppingItem) (~10분)

**Files:**
- Create: `lib/features/shopping_list/data/mappers/shopping_item_mapper.dart`
- Test: `test/features/shopping_list/data/shopping_item_mapper_test.dart`

**Interfaces:**
- Consumes: `ShoppingItemRow`(Task 2), `ShoppingItem`(Task 1).
- Produces: `ShoppingItem toEntity(ShoppingItemRow row)` (최상위 함수).

- [ ] **Step 1: Write the failing test**

`test/features/shopping_list/data/shopping_item_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/data/mappers/shopping_item_mapper.dart';

void main() {
  test('maps a Drift row to a domain entity field-for-field', () {
    final row = ShoppingItemRow(
      id: 7,
      name: '물티슈',
      quantity: 3,
      isDone: true,
      createdAt: DateTime(2026, 9, 17),
    );

    final entity = toEntity(row);

    expect(entity.id, 7);
    expect(entity.name, '물티슈');
    expect(entity.quantity, 3);
    expect(entity.isDone, isTrue);
    expect(entity.createdAt, DateTime(2026, 9, 17));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/shopping_list/data/shopping_item_mapper_test.dart`
Expected: FAIL — `toEntity` 미정의.

- [ ] **Step 3: Write the mapper**

`lib/features/shopping_list/data/mappers/shopping_item_mapper.dart`:

```dart
import '../../../../core/database/app_database.dart';
import '../../domain/entities/shopping_item.dart';

ShoppingItem toEntity(ShoppingItemRow row) => ShoppingItem(
      id: row.id,
      name: row.name,
      quantity: row.quantity,
      isDone: row.isDone,
      createdAt: row.createdAt,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/shopping_list/data/shopping_item_mapper_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/shopping_list/data/mappers test/features/shopping_list/data/shopping_item_mapper_test.dart
git commit -m "feat(data): add ShoppingItemRow to entity mapper"
```

---

### Task 4: 로컬 datasource (Drift CRUD + 정렬) (~30분)

**Files:**
- Create: `lib/features/shopping_list/data/datasources/shopping_item_local_datasource.dart`
- Test: `test/features/shopping_list/data/shopping_item_local_datasource_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ShoppingItemRow`, `ShoppingItemsCompanion`(Task 2).
- Produces: `class ShoppingItemLocalDataSource`
  - `ShoppingItemLocalDataSource(AppDatabase db)`
  - `Stream<List<ShoppingItemRow>> watchAll()` — `ORDER BY is_done ASC, created_at ASC`
  - `Future<int> insert(String name)` — quantity 기본 1, createdAt=now
  - `Future<void> updateName(int id, String name)`
  - `Future<void> updateQuantity(int id, int quantity)`
  - `Future<void> updateDone(int id, bool isDone)`
  - `Future<void> deleteById(int id)`

- [ ] **Step 1: Write the failing test**

`test/features/shopping_list/data/shopping_item_local_datasource_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/data/datasources/shopping_item_local_datasource.dart';

void main() {
  late AppDatabase db;
  late ShoppingItemLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = ShoppingItemLocalDataSource(db);
  });
  tearDown(() => db.close());

  test('insert stores name with default quantity 1 and not done', () async {
    final id = await ds.insert('건전지');
    final row = (await ds.watchAll().first).single;
    expect(row.id, id);
    expect(row.name, '건전지');
    expect(row.quantity, 1);
    expect(row.isDone, isFalse);
  });

  test('watchAll orders incomplete before done, each by createdAt', () async {
    final a = await ds.insert('A'); // oldest
    final b = await ds.insert('B');
    final c = await ds.insert('C');
    await ds.updateDone(a, true); // A done → should sink to bottom

    final names = (await ds.watchAll().first).map((r) => r.name).toList();
    expect(names, ['B', 'C', 'A']);
  });

  test('updateName / updateQuantity / updateDone mutate the row', () async {
    final id = await ds.insert('X');
    await ds.updateName(id, 'Y');
    await ds.updateQuantity(id, 4);
    await ds.updateDone(id, true);
    final row = (await ds.watchAll().first).single;
    expect(row.name, 'Y');
    expect(row.quantity, 4);
    expect(row.isDone, isTrue);
  });

  test('deleteById removes the row', () async {
    final id = await ds.insert('X');
    await ds.deleteById(id);
    expect(await ds.watchAll().first, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/shopping_list/data/shopping_item_local_datasource_test.dart`
Expected: FAIL — `ShoppingItemLocalDataSource` 미정의.

- [ ] **Step 3: Write the datasource**

`lib/features/shopping_list/data/datasources/shopping_item_local_datasource.dart`:

```dart
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class ShoppingItemLocalDataSource {
  ShoppingItemLocalDataSource(this._db);

  final AppDatabase _db;

  Stream<List<ShoppingItemRow>> watchAll() {
    return (_db.select(_db.shoppingItems)
          ..orderBy([
            (t) => OrderingTerm(expression: t.isDone),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Future<int> insert(String name) {
    return _db.into(_db.shoppingItems).insert(
          ShoppingItemsCompanion.insert(name: name, createdAt: DateTime.now()),
        );
  }

  Future<void> updateName(int id, String name) {
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(name: Value(name)));
  }

  Future<void> updateQuantity(int id, int quantity) {
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(quantity: Value(quantity)));
  }

  Future<void> updateDone(int id, bool isDone) {
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(isDone: Value(isDone)));
  }

  Future<void> deleteById(int id) {
    return (_db.delete(_db.shoppingItems)..where((t) => t.id.equals(id))).go();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/shopping_list/data/shopping_item_local_datasource_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/shopping_list/data/datasources test/features/shopping_list/data/shopping_item_local_datasource_test.dart
git commit -m "feat(data): add shopping item local datasource with sorted watch"
```

---

### Task 5: repository 구현 (~30분)

**Files:**
- Create: `lib/features/shopping_list/data/repositories/shopping_item_repository_impl.dart`
- Test: `test/features/shopping_list/data/shopping_item_repository_impl_test.dart`

**Interfaces:**
- Consumes: `ShoppingItemRepository`(Task 1), `ShoppingItemLocalDataSource`(Task 4), `toEntity`(Task 3), `AppDatabase`(Task 2).
- Produces: `class ShoppingItemRepositoryImpl implements ShoppingItemRepository` — 생성자 `ShoppingItemRepositoryImpl(ShoppingItemLocalDataSource ds)`. `add`/`rename`은 trim 후 공백이면 no-op, `setQuantity`는 1 미만→1 보정.

- [ ] **Step 1: Write the failing test**

`test/features/shopping_list/data/shopping_item_repository_impl_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/data/datasources/shopping_item_local_datasource.dart';
import 'package:daijo/features/shopping_list/data/repositories/shopping_item_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ShoppingItemRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ShoppingItemRepositoryImpl(ShoppingItemLocalDataSource(db));
  });
  tearDown(() => db.close());

  test('add inserts a domain entity with quantity 1', () async {
    await repo.add('수세미');
    final items = await repo.watchAll().first;
    expect(items.single.name, '수세미');
    expect(items.single.quantity, 1);
    expect(items.single.isDone, isFalse);
  });

  test('add ignores blank names after trim', () async {
    await repo.add('   ');
    expect(await repo.watchAll().first, isEmpty);
  });

  test('add trims surrounding whitespace', () async {
    await repo.add('  건전지  ');
    expect((await repo.watchAll().first).single.name, '건전지');
  });

  test('setQuantity clamps values below 1 up to 1', () async {
    await repo.add('X');
    final id = (await repo.watchAll().first).single.id;
    await repo.setQuantity(id, 0);
    expect((await repo.watchAll().first).single.quantity, 1);
  });

  test('setDone and delete work end to end', () async {
    await repo.add('X');
    final id = (await repo.watchAll().first).single.id;
    await repo.setDone(id, true);
    expect((await repo.watchAll().first).single.isDone, isTrue);
    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/shopping_list/data/shopping_item_repository_impl_test.dart`
Expected: FAIL — `ShoppingItemRepositoryImpl` 미정의.

- [ ] **Step 3: Write the repository implementation**

`lib/features/shopping_list/data/repositories/shopping_item_repository_impl.dart`:

```dart
import '../../domain/entities/shopping_item.dart';
import '../../domain/repositories/shopping_item_repository.dart';
import '../datasources/shopping_item_local_datasource.dart';
import '../mappers/shopping_item_mapper.dart';

class ShoppingItemRepositoryImpl implements ShoppingItemRepository {
  ShoppingItemRepositoryImpl(this._ds);

  final ShoppingItemLocalDataSource _ds;

  @override
  Stream<List<ShoppingItem>> watchAll() {
    return _ds.watchAll().map((rows) => rows.map(toEntity).toList());
  }

  @override
  Future<void> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _ds.insert(trimmed);
  }

  @override
  Future<void> rename(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _ds.updateName(id, trimmed);
  }

  @override
  Future<void> setQuantity(int id, int quantity) {
    return _ds.updateQuantity(id, quantity < 1 ? 1 : quantity);
  }

  @override
  Future<void> setDone(int id, bool isDone) => _ds.updateDone(id, isDone);

  @override
  Future<void> delete(int id) => _ds.deleteById(id);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/shopping_list/data/shopping_item_repository_impl_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/shopping_list/data/repositories test/features/shopping_list/data/shopping_item_repository_impl_test.dart
git commit -m "feat(data): add shopping item repository implementation"
```

---

### Task 6: Riverpod providers + 컨트롤러 (~30분)

**Files:**
- Create: `lib/features/shopping_list/presentation/shopping_list_providers.dart`
- Test: `test/features/shopping_list/presentation/shopping_list_controller_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`(Task 2), `ShoppingItemLocalDataSource`(Task 4), `ShoppingItemRepositoryImpl`(Task 5), `ShoppingItemRepository`/`ShoppingItem`(Task 1).
- Produces:
  - `final appDatabaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError())` — main에서 override.
  - `final shoppingItemRepositoryProvider = Provider<ShoppingItemRepository>(...)` — db로 impl 조립.
  - `final shoppingItemsProvider = StreamProvider<List<ShoppingItem>>(...)` — repository.watchAll 구독.
  - `class ShoppingListController` — `add/rename/setQuantity/toggleDone/delete`; `add`는 컨트롤러에서도 빈 문자열 방어(위임은 repo).
  - `final shoppingListControllerProvider = Provider<ShoppingListController>(...)`.

- [ ] **Step 1: Write the failing test**

`test/features/shopping_list/presentation/shopping_list_controller_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

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

  test('add then stream emits the new item', () async {
    await container.read(shoppingListControllerProvider).add('수세미');
    final items = await container.read(shoppingItemsProvider.future);
    expect(items.single.name, '수세미');
  });

  test('toggleDone updates the item and reorders it last', () async {
    final c = container.read(shoppingListControllerProvider);
    await c.add('A');
    await c.add('B');
    final aId = (await container.read(shoppingItemsProvider.future)).first.id;
    await c.toggleDone(aId, true);
    final names =
        (await container.read(shoppingItemsProvider.future)).map((e) => e.name);
    expect(names, ['B', 'A']);
  });

  test('delete removes the item', () async {
    final c = container.read(shoppingListControllerProvider);
    await c.add('A');
    final id = (await container.read(shoppingItemsProvider.future)).single.id;
    await c.delete(id);
    expect(await container.read(shoppingItemsProvider.future), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/shopping_list/presentation/shopping_list_controller_test.dart`
Expected: FAIL — provider 심볼 미정의.

- [ ] **Step 3: Write providers + controller**

`lib/features/shopping_list/presentation/shopping_list_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/datasources/shopping_item_local_datasource.dart';
import '../data/repositories/shopping_item_repository_impl.dart';
import '../domain/entities/shopping_item.dart';
import '../domain/repositories/shopping_item_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

final shoppingItemRepositoryProvider = Provider<ShoppingItemRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ShoppingItemRepositoryImpl(ShoppingItemLocalDataSource(db));
});

final shoppingItemsProvider = StreamProvider<List<ShoppingItem>>((ref) {
  return ref.watch(shoppingItemRepositoryProvider).watchAll();
});

class ShoppingListController {
  ShoppingListController(this._repo);

  final ShoppingItemRepository _repo;

  Future<void> add(String name) {
    if (name.trim().isEmpty) return Future<void>.value();
    return _repo.add(name);
  }

  Future<void> rename(int id, String name) => _repo.rename(id, name);
  Future<void> setQuantity(int id, int quantity) =>
      _repo.setQuantity(id, quantity);
  Future<void> toggleDone(int id, bool isDone) => _repo.setDone(id, isDone);
  Future<void> delete(int id) => _repo.delete(id);
}

final shoppingListControllerProvider = Provider<ShoppingListController>(
  (ref) => ShoppingListController(ref.watch(shoppingItemRepositoryProvider)),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/shopping_list/presentation/shopping_list_controller_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/shopping_list/presentation/shopping_list_providers.dart test/features/shopping_list/presentation/shopping_list_controller_test.dart
git commit -m "feat(presentation): add shopping list providers and controller"
```

---

### Task 7: 버전 provider (package_info_plus) (~15분)

**Files:**
- Modify: `pubspec.yaml` (add `package_info_plus`)
- Create: `lib/features/shopping_list/presentation/app_version_provider.dart`
- Test: `test/features/shopping_list/presentation/app_version_provider_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces: `final appVersionProvider = FutureProvider<String>(...)` — `PackageInfo.fromPlatform().version` 반환. 위젯/테스트에서 override 가능.

- [ ] **Step 1: 의존성 추가**

Run: `fvm flutter pub add package_info_plus`
Expected: pubspec에 추가, 해석 성공.

- [ ] **Step 2: Write the failing test**

`test/features/shopping_list/presentation/app_version_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/presentation/app_version_provider.dart';

void main() {
  test('appVersionProvider can be overridden with a fixed version', () async {
    final container = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWith((ref) async => '9.9.9'),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(appVersionProvider.future), '9.9.9');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `fvm flutter test test/features/shopping_list/presentation/app_version_provider_test.dart`
Expected: FAIL — `appVersionProvider` 미정의.

- [ ] **Step 4: Write the provider**

`lib/features/shopping_list/presentation/app_version_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `fvm flutter test test/features/shopping_list/presentation/app_version_provider_test.dart`
Expected: PASS (1 test)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/shopping_list/presentation/app_version_provider.dart test/features/shopping_list/presentation/app_version_provider_test.dart
git commit -m "feat(presentation): add app version provider via package_info_plus"
```

---

### Task 8: 프레젠테이션 위젯 — 입력줄 + 항목 타일 (~50분)

**Files:**
- Create: `lib/features/shopping_list/presentation/widgets/add_item_field.dart`
- Create: `lib/features/shopping_list/presentation/widgets/shopping_item_tile.dart`
- Test: `test/features/shopping_list/presentation/widgets/add_item_field_test.dart`
- Test: `test/features/shopping_list/presentation/widgets/shopping_item_tile_test.dart`

**Interfaces:**
- Consumes: `ShoppingItem`(Task 1).
- Produces (둘 다 "덤" 위젯 — provider를 직접 읽지 않고 콜백으로 통신):
  - `class AddItemField extends StatefulWidget` — `AddItemField({required ValueChanged<String> onSubmit})`. 내부 `TextEditingController`, 제출(엔터 또는 ＋ 버튼) 시 trim 후 비어있지 않으면 `onSubmit(text)` 호출하고 입력 비움. 힌트 `살 물건 입력…`.
  - `class ShoppingItemTile extends StatefulWidget` — 생성자:
    ```dart
    ShoppingItemTile({
      required ShoppingItem item,
      required ValueChanged<bool> onToggleDone,
      required ValueChanged<String> onRename,
      required ValueChanged<int> onQuantityChanged,
      required VoidCallback onDelete,
    })
    ```
    체크박스(`onToggleDone`), 이름 탭 → 인라인 `TextField` 편집(제출 시 `onRename`), 스테퍼 －/＋(`onQuantityChanged(item.quantity±1)`, 1에서 － 비활성), 완료 시 이름 취소선+회색, `Dismissible`(endToStart, `onDelete`). 타일 key `ValueKey('tile-${item.id}')`, 체크박스 key `ValueKey('check-${item.id}')`, 감소 key `ValueKey('minus-${item.id}')`, 증가 key `ValueKey('plus-${item.id}')`.

- [ ] **Step 1: Write the failing tests**

`test/features/shopping_list/presentation/widgets/add_item_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/presentation/widgets/add_item_field.dart';

void main() {
  testWidgets('submits trimmed text and clears the field', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AddItemField(onSubmit: submitted.add)),
    ));

    await tester.enterText(find.byType(TextField), '  수세미  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, ['수세미']);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('does not submit blank input', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AddItemField(onSubmit: submitted.add)),
    ));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, isEmpty);
  });
}
```

`test/features/shopping_list/presentation/widgets/shopping_item_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/domain/entities/shopping_item.dart';
import 'package:daijo/features/shopping_list/presentation/widgets/shopping_item_tile.dart';

ShoppingItem _item({int qty = 1, bool done = false}) => ShoppingItem(
      id: 1,
      name: '수세미',
      quantity: qty,
      isDone: done,
      createdAt: DateTime(2026),
    );

Widget _host(ShoppingItemTile tile) =>
    MaterialApp(home: Scaffold(body: ListView(children: [tile])));

void main() {
  testWidgets('checkbox tap reports toggled value', (tester) async {
    final toggled = <bool>[];
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(),
      onToggleDone: toggled.add,
      onRename: (_) {},
      onQuantityChanged: (_) {},
      onDelete: () {},
    )));

    await tester.tap(find.byKey(const ValueKey('check-1')));
    await tester.pump();
    expect(toggled, [true]);
  });

  testWidgets('plus increments, minus at 1 is disabled', (tester) async {
    final quantities = <int>[];
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(qty: 1),
      onToggleDone: (_) {},
      onRename: (_) {},
      onQuantityChanged: quantities.add,
      onDelete: () {},
    )));

    await tester.tap(find.byKey(const ValueKey('plus-1')));
    await tester.pump();
    expect(quantities, [2]);

    await tester.tap(find.byKey(const ValueKey('minus-1')));
    await tester.pump();
    expect(quantities, [2]); // still only the increment; minus disabled at 1
  });

  testWidgets('tapping name shows an editable field that reports rename',
      (tester) async {
    final renamed = <String>[];
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(),
      onToggleDone: (_) {},
      onRename: renamed.add,
      onQuantityChanged: (_) {},
      onDelete: () {},
    )));

    await tester.tap(find.text('수세미'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '철수세미');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(renamed, ['철수세미']);
  });

  testWidgets('swiping the tile reports delete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(),
      onToggleDone: (_) {},
      onRename: (_) {},
      onQuantityChanged: (_) {},
      onDelete: () => deleted = true,
    )));

    await tester.fling(
        find.byKey(const ValueKey('tile-1')), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fvm flutter test test/features/shopping_list/presentation/widgets/`
Expected: FAIL — `AddItemField`/`ShoppingItemTile` 미정의.

- [ ] **Step 3: Write AddItemField**

`lib/features/shopping_list/presentation/widgets/add_item_field.dart`:

```dart
import 'package:flutter/material.dart';

class AddItemField extends StatefulWidget {
  const AddItemField({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<AddItemField> createState() => _AddItemFieldState();
}

class _AddItemFieldState extends State<AddItemField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: '살 물건 입력…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _submit,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write ShoppingItemTile**

`lib/features/shopping_list/presentation/widgets/shopping_item_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../../domain/entities/shopping_item.dart';

class ShoppingItemTile extends StatefulWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onToggleDone,
    required this.onRename,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  final ShoppingItem item;
  final ValueChanged<bool> onToggleDone;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDelete;

  @override
  State<ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends State<ShoppingItemTile> {
  bool _editing = false;
  late final TextEditingController _controller =
      TextEditingController(text: widget.item.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitRename() {
    final text = _controller.text.trim();
    setState(() => _editing = false);
    if (text.isNotEmpty && text != widget.item.name) {
      widget.onRename(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Dismissible(
      key: ValueKey('tile-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Checkbox(
          key: ValueKey('check-${item.id}'),
          value: item.isDone,
          onChanged: (v) => widget.onToggleDone(v ?? false),
        ),
        title: _editing
            ? TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitRename(),
                onTapOutside: (_) => _submitRename(),
              )
            : GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Text(
                  item.name,
                  style: item.isDone
                      ? const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('minus-${item.id}'),
              onPressed: item.quantity > 1
                  ? () => widget.onQuantityChanged(item.quantity - 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text('${item.quantity}'),
            IconButton(
              key: ValueKey('plus-${item.id}'),
              onPressed: () => widget.onQuantityChanged(item.quantity + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm flutter test test/features/shopping_list/presentation/widgets/`
Expected: PASS (add_item_field 2 + shopping_item_tile 4 = 6 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/features/shopping_list/presentation/widgets test/features/shopping_list/presentation/widgets
git commit -m "feat(presentation): add item input field and shopping item tile widgets"
```

---

### Task 9: 홈 페이지 조립 (~45분)

**Files:**
- Create: `lib/features/shopping_list/presentation/home_page.dart`
- Test: `test/features/shopping_list/presentation/home_page_test.dart`

**Interfaces:**
- Consumes: `shoppingItemsProvider`, `shoppingListControllerProvider`, `appDatabaseProvider`(Task 6), `appVersionProvider`(Task 7), `AddItemField`/`ShoppingItemTile`(Task 8), `AppDatabase`(Task 2), `ShoppingItem`(Task 1).
- Produces: `class HomePage extends ConsumerWidget` — AppBar `다이저`; 본문: `AddItemField`(→ controller.add) + 목록. 목록은 미완료 먼저 표시, 완료 항목이 있으면 `완료` 구분선 후 완료 항목. 빈 목록이면 안내 텍스트 `살 물건을 추가하세요.`(줄바꿈 포함). 하단 버전 푸터 `v<version>`(`appVersionProvider`, 로딩/에러 시 빈 문자열). 타일 콜백을 controller에 연결.

- [ ] **Step 1: Write the failing test**

`test/features/shopping_list/presentation/home_page_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/presentation/app_version_provider.dart';
import 'package:daijo/features/shopping_list/presentation/home_page.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

Widget _app(AppDatabase db) => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
      ],
      child: const MaterialApp(home: HomePage()),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('shows empty-state message and version footer', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    expect(find.textContaining('살 물건을 추가하세요'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
  });

  testWidgets('adding via the field shows the item', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '수세미');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('수세미'), findsOneWidget);
  });

  testWidgets('completing an item shows the 완료 divider', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '건전지');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('완료'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/shopping_list/presentation/home_page_test.dart`
Expected: FAIL — `HomePage` 미정의.

- [ ] **Step 3: Write the home page**

`lib/features/shopping_list/presentation/home_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/shopping_item.dart';
import 'app_version_provider.dart';
import 'shopping_list_providers.dart';
import 'widgets/add_item_field.dart';
import 'widgets/shopping_item_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingItemsProvider);
    final controller = ref.watch(shoppingListControllerProvider);
    final version = ref.watch(appVersionProvider).maybeWhen(
          data: (v) => 'v$v',
          orElse: () => '',
        );

    return Scaffold(
      appBar: AppBar(title: const Text('다이저')),
      body: Column(
        children: [
          AddItemField(onSubmit: controller.add),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (items) => _buildList(items, controller),
            ),
          ),
          if (version.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                version,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<ShoppingItem> items, ShoppingListController c) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '살 물건을 추가하세요.\n매장 근처에 가면 알려드릴게요.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final pending = items.where((i) => !i.isDone).toList();
    final done = items.where((i) => i.isDone).toList();

    return ListView(
      children: [
        for (final item in pending) _tile(item, c),
        if (done.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('완료', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        for (final item in done) _tile(item, c),
      ],
    );
  }

  Widget _tile(ShoppingItem item, ShoppingListController c) {
    return ShoppingItemTile(
      item: item,
      onToggleDone: (v) => c.toggleDone(item.id, v),
      onRename: (name) => c.rename(item.id, name),
      onQuantityChanged: (q) => c.setQuantity(item.id, q),
      onDelete: () => c.delete(item.id),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/shopping_list/presentation/home_page_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/shopping_list/presentation/home_page.dart test/features/shopping_list/presentation/home_page_test.dart
git commit -m "feat(presentation): assemble home page with list, divider, version footer"
```

---

### Task 10: 인트로 스플래시 페이지 (~25분)

**Files:**
- Create: `lib/features/intro/presentation/intro_page.dart`
- Test: `test/features/intro/presentation/intro_page_test.dart`

**Interfaces:**
- Consumes: 없음(홈 전환은 `onFinished` 콜백으로 테스트 격리).
- Produces: `class IntroPage extends StatefulWidget` — `IntroPage({Duration duration = const Duration(seconds: 2), VoidCallback? onFinished})`. 로고 자리표시자, 앱 이름 `다이저`, 백그라운드 위치 고지 문구, 하단 회사 표기. `duration` 후 `onFinished`가 있으면 호출, 없으면 `Navigator.pushReplacement`로 `HomePage`. 고지 문구에 `백그라운드` 단어 포함.

- [ ] **Step 1: Write the failing test**

`test/features/intro/presentation/intro_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/intro/presentation/intro_page.dart';

void main() {
  testWidgets('renders app name and background-location disclosure',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: IntroPage(onFinished: _noop)),
    ));

    expect(find.text('다이저'), findsOneWidget);
    expect(find.textContaining('백그라운드'), findsOneWidget);
  });

  testWidgets('calls onFinished after the duration elapses', (tester) async {
    var finished = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: IntroPage(
          duration: const Duration(milliseconds: 500),
          onFinished: () => finished = true,
        ),
      ),
    ));

    expect(finished, isFalse);
    await tester.pump(const Duration(milliseconds: 600));
    expect(finished, isTrue);
  });
}

void _noop() {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/intro/presentation/intro_page_test.dart`
Expected: FAIL — `IntroPage` 미정의.

- [ ] **Step 3: Write the intro page**

`lib/features/intro/presentation/intro_page.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../shopping_list/presentation/home_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({
    super.key,
    this.duration = const Duration(seconds: 2),
    this.onFinished,
  });

  final Duration duration;
  final VoidCallback? onFinished;

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _finish);
  }

  void _finish() {
    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                '다이저',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '잊지 마세요, 문 앞에서 알려드릴게요',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '다이저는 다이소 매장 근처에 도착하면 살 물건을 알려주기 위해, '
                  '앱을 사용하지 않는 동안에도 기기 위치를 백그라운드에서 확인합니다. '
                  '위치 정보는 기기에만 사용되며 외부로 전송되지 않습니다.',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

> **참고:** `Colors.black.withValues(alpha: 0.18)`는 Flutter 3.29의 최신 API다. 만약 analyze가 `withValues` 미해결을 내면 `Colors.black.withOpacity(0.18)`로 대체.

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/intro/presentation/intro_page_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/intro test/features/intro
git commit -m "feat(intro): add splash page with background-location disclosure"
```

---

### Task 11: 앱 조립 — app.dart + main.dart (~25분)

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart` (템플릿 전체 교체)
- Test: `test/features/intro/presentation/intro_page_test.dart` (이미 통과) — 추가 테스트 없음; 대신 `fvm flutter analyze` + 앱 부팅 확인.

**Interfaces:**
- Consumes: `AppDatabase`(Task 2), `appDatabaseProvider`(Task 6), `IntroPage`(Task 10).
- Produces:
  - `Future<AppDatabase> openAppDatabase()` — `path_provider` 문서 디렉터리에 `daijo.sqlite` 오픈.
  - `class DaijoApp extends StatelessWidget` — `MaterialApp(title: '다이저', theme: teal M3, home: IntroPage())`.
  - `Future<void> main()` — DB 오픈 → `ProviderScope(overrides: appDatabaseProvider) → runApp(DaijoApp)`.

- [ ] **Step 1: Write app.dart**

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'features/intro/presentation/intro_page.dart';

class DaijoApp extends StatelessWidget {
  const DaijoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다이저',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00897B),
        useMaterial3: true,
      ),
      home: const IntroPage(),
    );
  }
}
```

- [ ] **Step 2: Write main.dart (템플릿 교체)**

`lib/main.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'features/shopping_list/presentation/shopping_list_providers.dart';

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'daijo.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const DaijoApp(),
    ),
  );
}
```

> **참고:** `path`는 Flutter/drift가 이미 전이 의존성으로 가지고 있어 별도 추가 없이 import 가능하다. 만약 해석 실패 시 `fvm flutter pub add path`.

- [ ] **Step 3: Analyze + 전체 테스트**

Run: `fvm flutter analyze`
Expected: "No issues found!"

Run: `fvm flutter test`
Expected: 모든 태스크의 유닛/위젯 테스트 PASS.

- [ ] **Step 4: 부팅 스모크 확인 (에뮬레이터/기기)**

Run: `fvm flutter run`(에뮬레이터 실행 중일 때) 또는 `fvm flutter build apk --debug`로 빌드만 확인.
확인: 인트로 스플래시(고지 문구) → ~2초 후 홈. 홈에서 항목 추가/체크(하단 이동)/수량 스테퍼/스와이프 삭제 동작, 하단 버전 표시, 앱 재실행 후에도 목록 유지.
빌드/런타임 에러 발생 시 해결 후 `docs/troubleshooting/YYYY-MM-DD-<주제>.md`에 증상→원인→해결(→커밋) 기록.

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart lib/main.dart
git commit -m "feat: wire app entry with intro splash and persistent database"
```

---

## 완료 기준 (Definition of Done)

- 모든 유닛/위젯 테스트 통과, `fvm flutter analyze` 무경고.
- Clean Architecture 계층 준수: domain 파일이 외부 패키지를 import 하지 않음.
- 인트로 스플래시가 매 실행 시 뜨고 ~2초 후 홈으로 전환, 백그라운드 위치 고지 문구 노출.
- 홈에서 항목 추가(상단 입력줄)/이름 인라인 편집/수량 스테퍼/완료 취소선+하단 이동/스와이프 삭제가 동작하고 로컬에 영구 저장.
- 하단에 앱 버전(`v<version>`) 표시.
- 앱 재실행 후에도 목록이 유지된다(기기 스모크 확인).

## 예상 소요 시간 합계

| Task | 내용 | 예상 |
| --- | --- | --- |
| 1 | 도메인 엔티티 + repository 인터페이스 | ~15분 |
| 2 | Drift DB + 테이블 | ~25분 |
| 3 | 매퍼 | ~10분 |
| 4 | 로컬 datasource | ~30분 |
| 5 | repository 구현 | ~30분 |
| 6 | Riverpod providers + 컨트롤러 | ~30분 |
| 7 | 버전 provider(package_info_plus) | ~15분 |
| 8 | 위젯(입력줄 + 타일) | ~50분 |
| 9 | 홈 페이지 조립 | ~45분 |
| 10 | 인트로 스플래시 | ~25분 |
| 11 | 앱 조립(app/main) + 검증 | ~25분 |
| | **합계** | **~5시간** |

## 다음 페이지 (이 계획 비범위)

권한 온보딩(위치 "항상 허용"·알림), 매장 시드 적재, 가까운 20개 지오펜스 등록(150m), ENTER 알림, 알림 탭 진입. 각각 별도 브레인스토밍 → 계획 → 구현.
