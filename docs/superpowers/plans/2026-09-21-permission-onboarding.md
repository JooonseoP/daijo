# 권한 온보딩 구현 계획 (Permission Onboarding Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 첫 실행 시 위치("항상 허용")·알림 권한을 순차 안내/요청하는 논블로킹 온보딩 화면과, 권한 미허용을 재유도하는 홈 배너를 구현한다.

**Architecture:** Clean Architecture(feature-first). 플랫폼 권한은 `core/permissions/`의 순수 Dart 인터페이스 `PermissionService` 뒤로 격리하고, 실제 permission_handler/geolocator 구현만 그 뒤에 둔다. 온보딩 완료 여부는 Drift `app_settings` 키-값 테이블에 저장한다. 컨트롤러·프리퍼런스·배너는 fake 주입으로 기기 없이 단위 테스트한다.

**Tech Stack:** Flutter 3.29.2 (FVM), Riverpod 2.6.1, Drift 2.31, permission_handler 11.3.1, geolocator 14.0.2. 명령은 PowerShell에서 `fvm flutter ...` / `fvm dart ...`.

**Spec:** `docs/superpowers/specs/2026-09-21-permission-onboarding-design.md`

## Global Constraints

- 모든 Flutter/dart 명령은 **PowerShell**에서 `fvm flutter ...` / `fvm dart ...` 로 실행. 프로젝트 루트 `E:/Joonseo/dev_works/daijo`에서 실행.
- 생성 코드(`*.g.dart`)는 커밋한다. 스키마/테이블 추가 후 반드시 `fvm dart run build_runner build --delete-conflicting-outputs` 실행.
- `fvm flutter analyze` 항상 무경고 유지.
- Riverpod은 **2.x 유지**. permission_handler는 **11.3.1 핀 유지**(pubspec 주석 참고).
- 앱 표시명 카피는 **다이저**. 위치 항상 허용 요청 직전 Google Play prominent disclosure 문구 노출 필수.
- 상태 enum 값 이름은 정확히: `PermissionKind { locationWhenInUse, locationAlways, notification }`, `PermissionStatus { granted, denied, permanentlyDenied, notApplicable }`.
- 온보딩은 **논블로킹** — "시작하기"·"건너뛰기" 모두 완료 플래그 저장 후 홈으로 이동. 권한 거부해도 진행 가능.

**예상 총 소요:** 약 5.5~7시간 (8개 태스크).

---

### Task 1: AppSettings KV 테이블 + DAO + 마이그레이션

**예상 소요:** 40분

**Files:**
- Modify: `lib/core/database/app_database.dart`
- Regenerate: `lib/core/database/app_database.g.dart` (build_runner)
- Test: `test/core/database/app_settings_dao_test.dart`

**Interfaces:**
- Consumes: 없음 (기존 `AppDatabase`).
- Produces:
  - Drift 테이블 `AppSettings` (`@DataClassName('AppSettingRow')`, 컬럼 `key TEXT PK`, `value TEXT`).
  - `AppDatabase.schemaVersion == 2`.
  - `AppDatabase.getSetting(String key) -> Future<String?>`.
  - `AppDatabase.setSetting(String key, String value) -> Future<void>` (upsert).

- [ ] **Step 1: Write the failing test**

Create `test/core/database/app_settings_dao_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema version is 2', () {
    expect(db.schemaVersion, 2);
  });

  test('getSetting returns null for missing key', () async {
    expect(await db.getSetting('missing'), isNull);
  });

  test('setSetting then getSetting returns the value', () async {
    await db.setSetting('onboarding_completed', 'true');
    expect(await db.getSetting('onboarding_completed'), 'true');
  });

  test('setSetting upserts (idempotent) on same key', () async {
    await db.setSetting('k', 'a');
    await db.setSetting('k', 'b');
    expect(await db.getSetting('k'), 'b');
    final rows = await db.select(db.appSettings).get();
    expect(rows.length, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (PowerShell): `fvm flutter test test/core/database/app_settings_dao_test.dart`
Expected: FAIL — `appSettings`/`getSetting` 미정의 컴파일 에러.

- [ ] **Step 3: Add the table, migration, and KV helpers**

Edit `lib/core/database/app_database.dart` to:

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

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [ShoppingItems, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(appSettings);
          }
        },
      );

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingRow(key: key, value: value),
    );
  }
}
```

- [ ] **Step 4: Regenerate Drift code**

Run (PowerShell): `fvm dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` 갱신, 에러 없음.

- [ ] **Step 5: Run test to verify it passes**

Run: `fvm flutter test test/core/database/app_settings_dao_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Analyze + commit**

```bash
fvm flutter analyze
git add lib/core/database/app_database.dart lib/core/database/app_database.g.dart test/core/database/app_settings_dao_test.dart
git commit -m "feat(db): add app_settings KV table, DAO helpers, v2 migration"
```

---

### Task 2: OnboardingPreferences (인터페이스 + Drift 구현)

**예상 소요:** 30분

**Files:**
- Create: `lib/features/onboarding/domain/repositories/onboarding_preferences.dart`
- Create: `lib/features/onboarding/data/repositories/onboarding_preferences_impl.dart`
- Test: `test/features/onboarding/data/onboarding_preferences_impl_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.getSetting` / `setSetting` (Task 1).
- Produces:
  - `abstract interface class OnboardingPreferences { Future<bool> isCompleted(); Future<void> setCompleted(); }`
  - `class DriftOnboardingPreferences implements OnboardingPreferences` — 생성자 `DriftOnboardingPreferences(AppDatabase db)`. 저장 키는 `'onboarding_completed'`, 값 `'true'`.

- [ ] **Step 1: Write the failing test**

Create `test/features/onboarding/data/onboarding_preferences_impl_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/onboarding/data/repositories/onboarding_preferences_impl.dart';

void main() {
  late AppDatabase db;
  late DriftOnboardingPreferences prefs;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    prefs = DriftOnboardingPreferences(db);
  });
  tearDown(() => db.close());

  test('isCompleted is false before setCompleted', () async {
    expect(await prefs.isCompleted(), isFalse);
  });

  test('isCompleted is true after setCompleted', () async {
    await prefs.setCompleted();
    expect(await prefs.isCompleted(), isTrue);
  });

  test('setCompleted is idempotent', () async {
    await prefs.setCompleted();
    await prefs.setCompleted();
    expect(await prefs.isCompleted(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/onboarding/data/onboarding_preferences_impl_test.dart`
Expected: FAIL — 클래스 미정의.

- [ ] **Step 3: Write interface + impl**

Create `lib/features/onboarding/domain/repositories/onboarding_preferences.dart`:

```dart
abstract interface class OnboardingPreferences {
  Future<bool> isCompleted();
  Future<void> setCompleted();
}
```

Create `lib/features/onboarding/data/repositories/onboarding_preferences_impl.dart`:

```dart
import '../../../../core/database/app_database.dart';
import '../../domain/repositories/onboarding_preferences.dart';

class DriftOnboardingPreferences implements OnboardingPreferences {
  DriftOnboardingPreferences(this._db);

  final AppDatabase _db;
  static const _key = 'onboarding_completed';

  @override
  Future<bool> isCompleted() async => await _db.getSetting(_key) == 'true';

  @override
  Future<void> setCompleted() => _db.setSetting(_key, 'true');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/onboarding/data/onboarding_preferences_impl_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyze + commit**

```bash
fvm flutter analyze
git add lib/features/onboarding/domain lib/features/onboarding/data test/features/onboarding/data
git commit -m "feat(onboarding): OnboardingPreferences interface + Drift-backed impl"
```

---

### Task 3: PermissionService 인터페이스 + OnboardingController + providers

**예상 소요:** 1시간

**Files:**
- Create: `lib/core/permissions/permission_service.dart`
- Create: `lib/core/permissions/permission_providers.dart`
- Create: `lib/features/onboarding/presentation/onboarding_controller.dart`
- Create: `lib/features/onboarding/presentation/onboarding_providers.dart`
- Test: `test/features/onboarding/presentation/onboarding_controller_test.dart`

**Interfaces:**
- Consumes: `OnboardingPreferences` (Task 2), `appDatabaseProvider` (기존 `shopping_list_providers.dart`).
- Produces:
  - `enum PermissionKind { locationWhenInUse, locationAlways, notification }`
  - `enum PermissionStatus { granted, denied, permanentlyDenied, notApplicable }`
  - `abstract interface class PermissionService { Future<PermissionStatus> check(PermissionKind kind); Future<PermissionStatus> request(PermissionKind kind); Future<void> openAppSettings(); }`
  - `class OnboardingState` — 필드 `whenInUse`, `always`, `notification` (모두 `PermissionStatus`), getter `bool get alwaysUnlocked`, `copyWith(...)`.
  - `class OnboardingController extends StateNotifier<OnboardingState>` — 메서드 `Future<void> refresh()`, `requestWhenInUse()`, `requestAlways()`, `requestNotification()`, `Future<void> complete()`.
  - Providers: `permissionServiceProvider` (Provider<PermissionService>, override 전까지 throw), `onboardingPreferencesProvider` (Provider<OnboardingPreferences>), `onboardingControllerProvider` (StateNotifierProvider<OnboardingController, OnboardingState>).

- [ ] **Step 1: Write the failing test**

Create `test/features/onboarding/presentation/onboarding_controller_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/core/permissions/permission_providers.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_controller.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_providers.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

/// Configurable fake: returns queued statuses and records requests.
class FakePermissionService implements PermissionService {
  final Map<PermissionKind, PermissionStatus> checkResult = {
    PermissionKind.locationWhenInUse: PermissionStatus.denied,
    PermissionKind.locationAlways: PermissionStatus.denied,
    PermissionKind.notification: PermissionStatus.denied,
  };
  final Map<PermissionKind, PermissionStatus> requestResult = {};
  final List<PermissionKind> requested = [];
  int openSettingsCount = 0;

  @override
  Future<PermissionStatus> check(PermissionKind kind) async => checkResult[kind]!;

  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    requested.add(kind);
    return requestResult[kind] ?? checkResult[kind]!;
  }

  @override
  Future<void> openAppSettings() async => openSettingsCount++;
}

void main() {
  late AppDatabase db;
  late FakePermissionService svc;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = FakePermissionService();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      permissionServiceProvider.overrideWithValue(svc),
    ]);
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);

  test('refresh loads current statuses into state', () async {
    svc.checkResult[PermissionKind.locationWhenInUse] = PermissionStatus.granted;
    await controller().refresh();
    final s = container.read(onboardingControllerProvider);
    expect(s.whenInUse, PermissionStatus.granted);
    expect(s.always, PermissionStatus.denied);
  });

  test('alwaysUnlocked is false until whenInUse granted', () {
    expect(container.read(onboardingControllerProvider).alwaysUnlocked, isFalse);
  });

  test('requestAlways is a no-op while locked', () async {
    await controller().requestAlways();
    expect(svc.requested, isEmpty);
  });

  test('requestAlways proceeds once whenInUse granted', () async {
    svc.requestResult[PermissionKind.locationWhenInUse] = PermissionStatus.granted;
    await controller().requestWhenInUse();
    svc.requestResult[PermissionKind.locationAlways] = PermissionStatus.granted;
    await controller().requestAlways();
    expect(svc.requested,
        [PermissionKind.locationWhenInUse, PermissionKind.locationAlways]);
    expect(container.read(onboardingControllerProvider).always,
        PermissionStatus.granted);
  });

  test('complete persists the onboarding flag', () async {
    await controller().complete();
    final prefs = container.read(onboardingPreferencesProvider);
    expect(await prefs.isCompleted(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/onboarding/presentation/onboarding_controller_test.dart`
Expected: FAIL — 미정의 심볼.

- [ ] **Step 3: Write the PermissionService interface**

Create `lib/core/permissions/permission_service.dart`:

```dart
enum PermissionKind { locationWhenInUse, locationAlways, notification }

enum PermissionStatus { granted, denied, permanentlyDenied, notApplicable }

abstract interface class PermissionService {
  Future<PermissionStatus> check(PermissionKind kind);
  Future<PermissionStatus> request(PermissionKind kind);
  Future<void> openAppSettings();
}
```

- [ ] **Step 4: Write the controller + state**

Create `lib/features/onboarding/presentation/onboarding_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_service.dart';
import '../domain/repositories/onboarding_preferences.dart';

class OnboardingState {
  const OnboardingState({
    this.whenInUse = PermissionStatus.denied,
    this.always = PermissionStatus.denied,
    this.notification = PermissionStatus.denied,
  });

  final PermissionStatus whenInUse;
  final PermissionStatus always;
  final PermissionStatus notification;

  bool get alwaysUnlocked => whenInUse == PermissionStatus.granted;

  OnboardingState copyWith({
    PermissionStatus? whenInUse,
    PermissionStatus? always,
    PermissionStatus? notification,
  }) {
    return OnboardingState(
      whenInUse: whenInUse ?? this.whenInUse,
      always: always ?? this.always,
      notification: notification ?? this.notification,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this._permissions, this._prefs)
      : super(const OnboardingState());

  final PermissionService _permissions;
  final OnboardingPreferences _prefs;

  Future<void> refresh() async {
    final whenInUse =
        await _permissions.check(PermissionKind.locationWhenInUse);
    final always = await _permissions.check(PermissionKind.locationAlways);
    final notification =
        await _permissions.check(PermissionKind.notification);
    state = OnboardingState(
      whenInUse: whenInUse,
      always: always,
      notification: notification,
    );
  }

  Future<void> requestWhenInUse() async {
    final status =
        await _permissions.request(PermissionKind.locationWhenInUse);
    state = state.copyWith(whenInUse: status);
  }

  Future<void> requestAlways() async {
    if (!state.alwaysUnlocked) return;
    final status = await _permissions.request(PermissionKind.locationAlways);
    state = state.copyWith(always: status);
  }

  Future<void> requestNotification() async {
    final status = await _permissions.request(PermissionKind.notification);
    state = state.copyWith(notification: status);
  }

  Future<void> openSettings() => _permissions.openAppSettings();

  Future<void> complete() => _prefs.setCompleted();
}
```

- [ ] **Step 5: Write the providers**

Create `lib/core/permissions/permission_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => throw UnimplementedError(
    'permissionServiceProvider must be overridden',
  ),
);
```

Create `lib/features/onboarding/presentation/onboarding_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_providers.dart';
import '../../shopping_list/presentation/shopping_list_providers.dart';
import '../data/repositories/onboarding_preferences_impl.dart';
import '../domain/repositories/onboarding_preferences.dart';
import 'onboarding_controller.dart';

final onboardingPreferencesProvider = Provider<OnboardingPreferences>((ref) {
  return DriftOnboardingPreferences(ref.watch(appDatabaseProvider));
});

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController(
    ref.watch(permissionServiceProvider),
    ref.watch(onboardingPreferencesProvider),
  );
});
```

- [ ] **Step 6: Run test to verify it passes**

Run: `fvm flutter test test/features/onboarding/presentation/onboarding_controller_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 7: Analyze + commit**

```bash
fvm flutter analyze
git add lib/core/permissions lib/features/onboarding/presentation/onboarding_controller.dart lib/features/onboarding/presentation/onboarding_providers.dart test/features/onboarding/presentation/onboarding_controller_test.dart
git commit -m "feat(onboarding): PermissionService interface, OnboardingController, providers"
```

---

### Task 4: PermissionStepTile 위젯

**예상 소요:** 45분

**Files:**
- Create: `lib/features/onboarding/presentation/widgets/permission_step_tile.dart`
- Test: `test/features/onboarding/presentation/widgets/permission_step_tile_test.dart`

**Interfaces:**
- Consumes: `PermissionStatus` (Task 3).
- Produces:
  - `class PermissionStepTile extends StatelessWidget` — 생성자 명명 인자: `required String title`, `required String description`, `required IconData icon`, `required PermissionStatus status`, `bool locked = false`, `String? disclosure`, `VoidCallback? onRequest`, `VoidCallback? onOpenSettings`.
  - 렌더 규칙: `locked==true` → "잠김" 표시, 버튼 없음. `status==granted` → "허용됨" 체크(버튼 없음). `status==permanentlyDenied` → "설정 열기" 버튼(`onOpenSettings`). 그 외 → "허용"(또는 disclosure 있으면 "설정에서 허용") 버튼(`onRequest`). `disclosure != null` → disclosure 텍스트 노출.

- [ ] **Step 1: Write the failing test**

Create `test/features/onboarding/presentation/widgets/permission_step_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/features/onboarding/presentation/widgets/permission_step_tile.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('denied shows request button and fires onRequest', (t) async {
    var tapped = 0;
    await t.pumpWidget(_host(PermissionStepTile(
      title: '위치 (앱 사용 중)',
      description: '가까운 매장을 찾기 위해 필요해요.',
      icon: Icons.location_on,
      status: PermissionStatus.denied,
      onRequest: () => tapped++,
    )));
    expect(find.text('위치 (앱 사용 중)'), findsOneWidget);
    await t.tap(find.text('허용'));
    expect(tapped, 1);
  });

  testWidgets('granted shows granted mark and no request button', (t) async {
    await t.pumpWidget(_host(PermissionStepTile(
      title: '알림',
      description: '목록 알림을 위해 필요해요.',
      icon: Icons.notifications,
      status: PermissionStatus.granted,
      onRequest: () {},
    )));
    expect(find.text('허용됨'), findsOneWidget);
    expect(find.text('허용'), findsNothing);
  });

  testWidgets('locked shows lock text and no button', (t) async {
    await t.pumpWidget(_host(PermissionStepTile(
      title: '위치 항상 허용',
      description: '백그라운드 감지에 필요해요.',
      icon: Icons.my_location,
      status: PermissionStatus.denied,
      locked: true,
      onRequest: () {},
    )));
    expect(find.textContaining('잠김'), findsOneWidget);
    expect(find.text('허용'), findsNothing);
    expect(find.text('설정에서 허용'), findsNothing);
  });

  testWidgets('permanentlyDenied shows open-settings button', (t) async {
    var opened = 0;
    await t.pumpWidget(_host(PermissionStepTile(
      title: '알림',
      description: '목록 알림을 위해 필요해요.',
      icon: Icons.notifications,
      status: PermissionStatus.permanentlyDenied,
      onOpenSettings: () => opened++,
    )));
    await t.tap(find.text('설정 열기'));
    expect(opened, 1);
  });

  testWidgets('disclosure text is shown when provided', (t) async {
    await t.pumpWidget(_host(PermissionStepTile(
      title: '위치 항상 허용',
      description: '백그라운드 감지에 필요해요.',
      icon: Icons.my_location,
      status: PermissionStatus.denied,
      disclosure: '백그라운드에서 기기 위치를 확인합니다.',
      onRequest: () {},
    )));
    expect(find.textContaining('백그라운드에서 기기 위치'), findsOneWidget);
    expect(find.text('설정에서 허용'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/onboarding/presentation/widgets/permission_step_tile_test.dart`
Expected: FAIL — `PermissionStepTile` 미정의.

- [ ] **Step 3: Write the widget**

Create `lib/features/onboarding/presentation/widgets/permission_step_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/permissions/permission_service.dart';

class PermissionStepTile extends StatelessWidget {
  const PermissionStepTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.locked = false,
    this.disclosure,
    this.onRequest,
    this.onOpenSettings,
  });

  final String title;
  final String description;
  final IconData icon;
  final PermissionStatus status;
  final bool locked;
  final String? disclosure;
  final VoidCallback? onRequest;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        if (locked)
                          const Text('🔒 잠김',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodySmall),
                    if (disclosure != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(disclosure!,
                            style: const TextStyle(
                                fontSize: 12, height: 1.5, color: Color(0xFF8A6D00))),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _trailing(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    if (locked) return const SizedBox.shrink();
    if (status == PermissionStatus.granted) {
      return const Row(children: [
        Icon(Icons.check_circle, color: Colors.green, size: 18),
        SizedBox(width: 6),
        Text('허용됨', style: TextStyle(color: Colors.green)),
      ]);
    }
    if (status == PermissionStatus.permanentlyDenied) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(onPressed: onOpenSettings, child: const Text('설정 열기')),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: onRequest,
        child: Text(disclosure != null ? '설정에서 허용' : '허용'),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/onboarding/presentation/widgets/permission_step_tile_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Analyze + commit**

```bash
fvm flutter analyze
git add lib/features/onboarding/presentation/widgets/permission_step_tile.dart test/features/onboarding/presentation/widgets/permission_step_tile_test.dart
git commit -m "feat(onboarding): PermissionStepTile widget with state-driven trailing"
```

---

### Task 5: OnboardingPage

**예상 소요:** 1시간

**Files:**
- Create: `lib/features/onboarding/presentation/onboarding_page.dart`
- Test: `test/features/onboarding/presentation/onboarding_page_test.dart`

**Interfaces:**
- Consumes: `onboardingControllerProvider`, `permissionServiceProvider`, `onboardingPreferencesProvider` (Task 3), `PermissionStepTile` (Task 4), `HomePage` (기존).
- Produces:
  - `class OnboardingPage extends ConsumerStatefulWidget` — 생성자 `const OnboardingPage({super.key, this.onFinished})`. `VoidCallback? onFinished` 제공 시 완료/건너뛰기가 이를 호출(테스트·라우팅 주입용), 미제공 시 `HomePage`로 `pushReplacement`.
  - `initState`에서 `onboardingControllerProvider.notifier.refresh()` 호출.
  - "시작하기" CTA와 "권한 없이 목록만 사용할게요" 건너뛰기 둘 다 `controller.complete()` 후 `onFinished`(또는 HomePage 이동).

- [ ] **Step 1: Write the failing test**

Create `test/features/onboarding/presentation/onboarding_page_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/core/permissions/permission_providers.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_page.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_providers.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

class FakePermissionService implements PermissionService {
  final Map<PermissionKind, PermissionStatus> result = {
    PermissionKind.locationWhenInUse: PermissionStatus.denied,
    PermissionKind.locationAlways: PermissionStatus.denied,
    PermissionKind.notification: PermissionStatus.denied,
  };
  @override
  Future<PermissionStatus> check(PermissionKind kind) async => result[kind]!;
  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    result[kind] = PermissionStatus.granted;
    return PermissionStatus.granted;
  }
  @override
  Future<void> openAppSettings() async {}
}

void main() {
  late AppDatabase db;
  late FakePermissionService svc;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = FakePermissionService();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester t, {VoidCallback? onFinished}) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        permissionServiceProvider.overrideWithValue(svc),
      ],
      child: MaterialApp(home: OnboardingPage(onFinished: onFinished)),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('renders three permission steps and CTA', (t) async {
    await pump(t);
    expect(find.text('위치 (앱 사용 중)'), findsOneWidget);
    expect(find.text('위치 항상 허용'), findsOneWidget);
    expect(find.text('알림'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('always step is locked until whenInUse granted', (t) async {
    await pump(t);
    expect(find.textContaining('잠김'), findsOneWidget);
    // Grant whenInUse via its request button.
    await t.tap(find.text('허용').first);
    await t.pumpAndSettle();
    expect(find.textContaining('잠김'), findsNothing);
  });

  testWidgets('start button completes onboarding and calls onFinished', (t) async {
    var finished = 0;
    await pump(t, onFinished: () => finished++);
    await t.tap(find.text('시작하기'));
    await t.pumpAndSettle();
    expect(finished, 1);
    expect(await DriftPrefsProbe(db).completed(), isTrue);
  });

  testWidgets('skip also completes onboarding and calls onFinished', (t) async {
    var finished = 0;
    await pump(t, onFinished: () => finished++);
    await t.tap(find.text('권한 없이 목록만 사용할게요'));
    await t.pumpAndSettle();
    expect(finished, 1);
    expect(await DriftPrefsProbe(db).completed(), isTrue);
  });
}

/// Small probe to read the persisted flag without importing the impl class name
/// into assertions repeatedly.
class DriftPrefsProbe {
  DriftPrefsProbe(this.db);
  final AppDatabase db;
  Future<bool> completed() async =>
      await db.getSetting('onboarding_completed') == 'true';
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/onboarding/presentation/onboarding_page_test.dart`
Expected: FAIL — `OnboardingPage` 미정의.

- [ ] **Step 3: Write the page**

Create `lib/features/onboarding/presentation/onboarding_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_service.dart';
import '../../shopping_list/presentation/home_page.dart';
import 'onboarding_controller.dart';
import 'onboarding_providers.dart';
import 'widgets/permission_step_tile.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingControllerProvider.notifier).refresh();
    });
  }

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: theme.colorScheme.primary,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 30),
                  const SizedBox(height: 10),
                  Text('문 앞에서 알려드릴게요',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    '다이소 매장 근처에 도착하면 살 물건을 알림으로 보여드려요. 이를 위해 아래 권한이 필요해요.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  PermissionStepTile(
                    title: '위치 (앱 사용 중)',
                    description: '가까운 다이소 매장을 찾기 위해 현재 위치를 사용해요.',
                    icon: Icons.location_on,
                    status: state.whenInUse,
                    onRequest: controller.requestWhenInUse,
                    onOpenSettings: controller.openSettings,
                  ),
                  PermissionStepTile(
                    title: '위치 항상 허용',
                    description: '앱을 켜지 않아도 매장 근처 진입을 감지하려면 필요해요.',
                    icon: Icons.my_location,
                    status: state.always,
                    locked: !state.alwaysUnlocked,
                    disclosure:
                        '다이저는 매장 근처 알림을 위해 백그라운드에서 기기 위치를 확인합니다. '
                        '위치는 기기에만 사용되며 외부로 전송되지 않습니다.',
                    onRequest: controller.requestAlways,
                    onOpenSettings: controller.openSettings,
                  ),
                  PermissionStepTile(
                    title: '알림',
                    description: '매장 근처에서 쇼핑 목록을 알림으로 보여주기 위해 필요해요.',
                    icon: Icons.notifications,
                    status: state.notification,
                    onRequest: controller.requestNotification,
                    onOpenSettings: controller.openSettings,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('시작하기'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('권한 없이 목록만 사용할게요'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/onboarding/presentation/onboarding_page_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyze + commit**

```bash
fvm flutter analyze
git add lib/features/onboarding/presentation/onboarding_page.dart test/features/onboarding/presentation/onboarding_page_test.dart
git commit -m "feat(onboarding): OnboardingPage with sequential permission steps and skip"
```

---

### Task 6: 홈 배너 (permissionSummaryProvider + PermissionBanner + HomePage 통합)

**예상 소요:** 50분

**Files:**
- Create: `lib/features/shopping_list/presentation/permission_status_provider.dart`
- Create: `lib/features/shopping_list/presentation/widgets/permission_banner.dart`
- Modify: `lib/features/shopping_list/presentation/home_page.dart`
- Test: `test/features/shopping_list/presentation/widgets/permission_banner_test.dart`

**Interfaces:**
- Consumes: `permissionServiceProvider`, `PermissionKind`, `PermissionStatus` (Task 3).
- Produces:
  - `class PermissionSummary` — 필드 `PermissionStatus always`, `PermissionStatus notification`; getter `bool get geofencingReady` (`always==granted` && (`notification==granted` || `notification==notApplicable`)).
  - `permissionSummaryProvider` (FutureProvider<PermissionSummary>).
  - `class PermissionBanner extends StatelessWidget` — 생성자 `const PermissionBanner({super.key, required this.onTap})`; `VoidCallback onTap`.
  - `HomePage` 상단(AddItemField 위)에 배너: `permissionSummaryProvider`가 data이고 `!geofencingReady`일 때만 표시. 탭 시 `OnboardingPage`로 이동.

- [ ] **Step 1: Write the failing test**

Create `test/features/shopping_list/presentation/widgets/permission_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/features/shopping_list/presentation/permission_status_provider.dart';
import 'package:daijo/features/shopping_list/presentation/widgets/permission_banner.dart';

void main() {
  test('geofencingReady true only when always granted and notification ok', () {
    expect(
      const PermissionSummary(
        always: PermissionStatus.granted,
        notification: PermissionStatus.granted,
      ).geofencingReady,
      isTrue,
    );
    expect(
      const PermissionSummary(
        always: PermissionStatus.granted,
        notification: PermissionStatus.notApplicable,
      ).geofencingReady,
      isTrue,
    );
    expect(
      const PermissionSummary(
        always: PermissionStatus.denied,
        notification: PermissionStatus.granted,
      ).geofencingReady,
      isFalse,
    );
  });

  testWidgets('banner renders message and fires onTap', (t) async {
    var tapped = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: PermissionBanner(onTap: () => tapped++)),
    ));
    expect(find.textContaining('알림이 꺼져 있어요'), findsOneWidget);
    await t.tap(find.byType(PermissionBanner));
    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/shopping_list/presentation/widgets/permission_banner_test.dart`
Expected: FAIL — 미정의 심볼.

- [ ] **Step 3: Write the provider + summary**

Create `lib/features/shopping_list/presentation/permission_status_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_providers.dart';
import '../../../core/permissions/permission_service.dart';

class PermissionSummary {
  const PermissionSummary({required this.always, required this.notification});

  final PermissionStatus always;
  final PermissionStatus notification;

  bool get geofencingReady =>
      always == PermissionStatus.granted &&
      (notification == PermissionStatus.granted ||
          notification == PermissionStatus.notApplicable);
}

final permissionSummaryProvider = FutureProvider<PermissionSummary>((ref) async {
  final svc = ref.watch(permissionServiceProvider);
  return PermissionSummary(
    always: await svc.check(PermissionKind.locationAlways),
    notification: await svc.check(PermissionKind.notification),
  );
});
```

- [ ] **Step 4: Write the banner widget**

Create `lib/features/shopping_list/presentation/widgets/permission_banner.dart`:

```dart
import 'package:flutter/material.dart';

class PermissionBanner extends StatelessWidget {
  const PermissionBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          border: Border.all(color: const Color(0xFFFFE082)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFF8A6D00)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '매장 근처 알림이 꺼져 있어요. 위치 "항상 허용"과 알림 권한이 필요해요.',
                style: TextStyle(color: Color(0xFF8A6D00), fontSize: 13),
              ),
            ),
            const Text('권한 켜기 ›',
                style: TextStyle(
                    color: Color(0xFF00695C), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Integrate into HomePage**

In `lib/features/shopping_list/presentation/home_page.dart`, add imports:

```dart
import '../../onboarding/presentation/onboarding_page.dart';
import 'permission_status_provider.dart';
import 'widgets/permission_banner.dart';
```

Then, inside `build`, insert the banner as the first child of the body `Column` (above `AddItemField`):

```dart
      body: Column(
        children: [
          ref.watch(permissionSummaryProvider).maybeWhen(
                data: (s) => s.geofencingReady
                    ? const SizedBox.shrink()
                    : PermissionBanner(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const OnboardingPage(),
                          ),
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
          AddItemField(onSubmit: controller.add),
          // ... existing children unchanged ...
```

- [ ] **Step 6: Run tests to verify pass (banner + existing home)**

Run: `fvm flutter test test/features/shopping_list/presentation/widgets/permission_banner_test.dart test/features/shopping_list/presentation/home_page_test.dart`
Expected: PASS. If `home_page_test.dart` fails to build the widget because `permissionServiceProvider` is now read, add `permissionServiceProvider.overrideWithValue(...)` with a fake in that test's ProviderScope (use a fake returning `granted` for both so no banner shows).

- [ ] **Step 7: Analyze + commit**

```bash
fvm flutter analyze
git add lib/features/shopping_list/presentation/permission_status_provider.dart lib/features/shopping_list/presentation/widgets/permission_banner.dart lib/features/shopping_list/presentation/home_page.dart test/features/shopping_list/presentation/widgets/permission_banner_test.dart test/features/shopping_list/presentation/home_page_test.dart
git commit -m "feat(home): permission summary provider + re-entry banner on HomePage"
```

---

### Task 7: PermissionServiceImpl (실 구현) + Android 매니페스트 권한 + main 배선

**예상 소요:** 1시간 (기기 스모크 포함)

**Files:**
- Create: `lib/core/permissions/permission_service_impl.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `PermissionService`, `PermissionKind`, `PermissionStatus` (Task 3), `permissionServiceProvider` (Task 3).
- Produces: `class PermissionHandlerService implements PermissionService` — permission_handler 매핑 구현. main.dart에서 `permissionServiceProvider.overrideWithValue(PermissionHandlerService())` 배선.

**Note:** 이 태스크는 플랫폼 의존이라 단위 테스트 대신 **기기/에뮬레이터 스모크**로 검증한다.

- [ ] **Step 1: Add Android permissions to the manifest**

In `android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` (above `<application>`):

```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- [ ] **Step 2: Write the implementation**

Create `lib/core/permissions/permission_service_impl.dart`:

```dart
import 'package:permission_handler/permission_handler.dart' as ph;

import 'permission_service.dart';

class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  ph.Permission _map(PermissionKind kind) {
    switch (kind) {
      case PermissionKind.locationWhenInUse:
        return ph.Permission.locationWhenInUse;
      case PermissionKind.locationAlways:
        return ph.Permission.locationAlways;
      case PermissionKind.notification:
        return ph.Permission.notification;
    }
  }

  PermissionStatus _status(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermissionStatus.granted;
    if (s.isPermanentlyDenied) return PermissionStatus.permanentlyDenied;
    if (s.isRestricted) return PermissionStatus.notApplicable;
    return PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> check(PermissionKind kind) async {
    return _status(await _map(kind).status);
  }

  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    return _status(await _map(kind).request());
  }

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}
```

- [ ] **Step 3: Wire the provider in main.dart**

In `lib/main.dart`, add import and override:

```dart
import 'core/permissions/permission_providers.dart';
import 'core/permissions/permission_service_impl.dart';
```

```dart
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
```

- [ ] **Step 4: Analyze + build check**

Run: `fvm flutter analyze`
Run: `fvm flutter build apk --debug`
Expected: 무경고, 빌드 성공.

- [ ] **Step 5: Commit**

```bash
git add lib/core/permissions/permission_service_impl.dart android/app/src/main/AndroidManifest.xml lib/main.dart
git commit -m "feat(permissions): permission_handler-backed PermissionService + manifest + wiring"
```

- [ ] **Step 6: Device smoke (manual, record any error to troubleshooting)**

기기/에뮬레이터에서 확인 (실패 시 `docs/troubleshooting/YYYY-MM-DD-*.md`에 증상→원인→해결 기록):
- 위치(사용중) 허용 다이얼로그 → 허용 후 "항상 허용" 카드 잠금 해제.
- "설정에서 허용" 탭 시 설정 딥링크, 허용 후 상태 반영.
- 알림 권한(Android 13+) 요청/반영.

---

### Task 8: 앱 진입 게이팅 (SplashGate: 인트로 → 온보딩/홈)

**예상 소요:** 40분

**Files:**
- Create: `lib/features/onboarding/presentation/splash_gate.dart`
- Modify: `lib/app.dart`
- Test: `test/features/onboarding/presentation/splash_gate_test.dart`

**Interfaces:**
- Consumes: `IntroPage` (기존, `onFinished` 콜백 지원), `onboardingPreferencesProvider` (Task 3), `OnboardingPage` (Task 5), `HomePage` (기존).
- Produces:
  - `class SplashGate extends ConsumerWidget` — `IntroPage`를 표시하고, `onFinished`에서 `onboardingPreferencesProvider.isCompleted()`를 읽어 `true`면 `HomePage`, `false`면 `OnboardingPage`로 `pushReplacement`.
  - `app.dart`의 `home:`를 `const SplashGate()`로 교체(단, `DaijoApp`은 그대로 `StatelessWidget` 유지 — SplashGate가 Consumer).

- [ ] **Step 1: Write the failing test**

Create `test/features/onboarding/presentation/splash_gate_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/core/permissions/permission_providers.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_page.dart';
import 'package:daijo/features/onboarding/presentation/splash_gate.dart';
import 'package:daijo/features/shopping_list/presentation/home_page.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

class GrantedPermissionService implements PermissionService {
  @override
  Future<PermissionStatus> check(PermissionKind kind) async =>
      PermissionStatus.granted;
  @override
  Future<PermissionStatus> request(PermissionKind kind) async =>
      PermissionStatus.granted;
  @override
  Future<void> openAppSettings() async {}
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        permissionServiceProvider.overrideWithValue(GrantedPermissionService()),
      ],
      // Zero-duration intro so the gate resolves immediately in tests.
      child: const MaterialApp(home: SplashGate(introDuration: Duration.zero)),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('first launch (flag unset) routes to OnboardingPage', (t) async {
    await pump(t);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('completed flag routes straight to HomePage', (t) async {
    await db.setSetting('onboarding_completed', 'true');
    await pump(t);
    expect(find.byType(HomePage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/onboarding/presentation/splash_gate_test.dart`
Expected: FAIL — `SplashGate` 미정의.

- [ ] **Step 3: Write SplashGate**

Create `lib/features/onboarding/presentation/splash_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../intro/presentation/intro_page.dart';
import '../../shopping_list/presentation/home_page.dart';
import 'onboarding_page.dart';
import 'onboarding_providers.dart';

class SplashGate extends ConsumerWidget {
  const SplashGate({super.key, this.introDuration = const Duration(seconds: 2)});

  final Duration introDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntroPage(
      duration: introDuration,
      onFinished: () async {
        final completed =
            await ref.read(onboardingPreferencesProvider).isCompleted();
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                completed ? const HomePage() : const OnboardingPage(),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Point app.dart at SplashGate**

In `lib/app.dart`, replace the intro import and `home:`:

```dart
import 'features/onboarding/presentation/splash_gate.dart';
```

```dart
      home: const SplashGate(),
```

(Remove the now-unused `import 'features/intro/presentation/intro_page.dart';`.)

- [ ] **Step 5: Run tests to verify pass**

Run: `fvm flutter test test/features/onboarding/presentation/splash_gate_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Full suite + analyze + commit**

```bash
fvm flutter test
fvm flutter analyze
git add lib/features/onboarding/presentation/splash_gate.dart lib/app.dart test/features/onboarding/presentation/splash_gate_test.dart
git commit -m "feat(app): SplashGate routes intro to onboarding or home by completion flag"
```

---

## 최종 검증 (플랜 완료 후)

- [ ] `fvm flutter test` — 전체 스위트 통과.
- [ ] `fvm flutter analyze` — 무경고.
- [ ] `fvm flutter build apk --debug` — 빌드 성공.
- [ ] 기기 스모크 (Task 7 Step 6 + 전체 흐름): 첫 실행 인트로→온보딩→홈, 재실행 홈 직행, 배너 재진입.
- [ ] worklog 갱신(`docs/worklog/YYYY-MM-DD.md` + README), 메모리 `daijo-project-status` 갱신.
- [ ] `superpowers:finishing-a-development-branch`로 통합 방식 결정.

## Self-Review 메모 (작성자 확인)

- 스펙 커버리지: 첫 실행 게이트(Task 8) · 순차 카드/잠금(Task 3·4·5) · 논블로킹 건너뛰기(Task 5) · disclosure(Task 4·5) · 홈 배너(Task 6) · 권한 추상화/impl(Task 3·7) · Drift KV 플래그+마이그레이션(Task 1·2) 모두 태스크로 매핑됨.
- enum/시그니처 일관성 확인: `PermissionKind`/`PermissionStatus` 값, `OnboardingController` 메서드명, `PermissionSummary.geofencingReady`가 태스크 간 동일.
- 플레이스홀더: 스캔 완료, 모든 코드 블록이 실제 내용으로 완결됨(잔여 placeholder 없음).
