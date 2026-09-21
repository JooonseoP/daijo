import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/permissions/permission_providers.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/features/shopping_list/presentation/app_version_provider.dart';
import 'package:daijo/features/shopping_list/presentation/home_page.dart';
import 'package:daijo/features/shopping_list/presentation/permission_status_provider.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:daijo/features/shopping_list/presentation/widgets/permission_banner.dart';

/// Fake PermissionService that returns [PermissionStatus.granted] for every
/// kind so that [permissionSummaryProvider] resolves to geofencingReady=true
/// and NO banner is shown — keeping existing assertions valid.
class _GrantedPermissionService implements PermissionService {
  const _GrantedPermissionService();

  @override
  Future<PermissionStatus> check(PermissionKind kind) async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> request(PermissionKind kind) async =>
      PermissionStatus.granted;

  @override
  Future<void> openAppSettings() async {}
}

/// Mutable fake whose [check] return value can be changed at runtime.
/// Used to simulate the user granting permissions after the banner is shown.
class _MutablePermissionService implements PermissionService {
  PermissionStatus status;

  _MutablePermissionService(this.status);

  @override
  Future<PermissionStatus> check(PermissionKind kind) async => status;

  @override
  Future<PermissionStatus> request(PermissionKind kind) async => status;

  @override
  Future<void> openAppSettings() async {}
}

Widget _app(AppDatabase db) => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
        permissionServiceProvider
            .overrideWithValue(const _GrantedPermissionService()),
      ],
      child: const MaterialApp(home: HomePage()),
    );

/// Waits for a Drift-backed stream emission, then rebuilds the widget.
///
/// Zone split: HomePage watches [shoppingItemsProvider], a StreamProvider backed
/// by Drift's live `.watch()`. The DB does *real* (non-fake) async work, so we
/// cross into the real-async zone via [WidgetTester.runAsync] to let that stream
/// actually emit the new row set. Back in the fake zone, a plain `pump()` (no
/// duration) rebuilds the tree with the fresh `AsyncData` without advancing the
/// fake clock. Disposal-timer flushing is NOT this helper's concern — see
/// [_teardown]. (`pumpAndSettle()` can't be used: the live `.watch()` stream
/// never quiesces under FakeAsync.)
Future<void> _flushStream(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump();
  await tester.pump();
}

/// Unmounts the ProviderScope and flushes Drift's disposal timer.
///
/// Zone split: unmounting triggers Drift's `StreamQueryStore.markAsClosed`, which
/// schedules a `Timer(Duration.zero)` *inside the FakeAsync zone*. Real async
/// (runAsync) can't clear a fake timer; only advancing the fake clock via
/// `pump(duration)` fires it. We do that here so the timer is gone before the
/// end-of-test `_verifyInvariants` pending-timer check runs. This is the ONLY
/// place the fake clock is advanced — the per-mutation stream flush must not.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // Fire Drift's zero-duration disposal timer on the fake clock.
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('shows empty-state message and version footer', (tester) async {
    // `finally` runs the disposal-timer flush unconditionally — even if an
    // assertion throws — so no live disposal timer leaks past this test. It
    // must run inside the test body (before the end-of-test pending-timer
    // invariant), which is why we don't use `addTearDown` here.
    try {
      await tester.pumpWidget(_app(db));
      await _flushStream(tester);

      expect(find.textContaining('살 물건을 추가하세요'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
    } finally {
      await _teardown(tester);
    }
  });

  testWidgets('adding via the field shows the item', (tester) async {
    try {
      await tester.pumpWidget(_app(db));
      await _flushStream(tester);

      await tester.enterText(find.byType(TextField), '수세미');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _flushStream(tester);

      expect(find.text('수세미'), findsOneWidget);
    } finally {
      await _teardown(tester);
    }
  });

  testWidgets('completing an item shows the 완료 divider', (tester) async {
    try {
      await tester.pumpWidget(_app(db));
      await _flushStream(tester);

      await tester.enterText(find.byType(TextField), '건전지');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _flushStream(tester);

      await tester.tap(find.byType(Checkbox).first);
      await _flushStream(tester);

      expect(find.text('완료'), findsOneWidget);
    } finally {
      await _teardown(tester);
    }
  });

  testWidgets('banner clears after permissionSummaryProvider is invalidated '
      'with granted status', (tester) async {
    // Arrange: mutable service that starts DENIED so banner appears.
    final fakeSvc = _MutablePermissionService(PermissionStatus.denied);

    // We need a ProviderContainer we can access to call invalidate after
    // flipping the fake. Wrap in a UncontrolledProviderScope so we own the
    // container's lifecycle.
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
        permissionServiceProvider.overrideWithValue(fakeSvc),
      ],
    );
    addTearDown(container.dispose);

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await _flushStream(tester);

      // Banner must be visible while permissions are denied.
      expect(find.byType(PermissionBanner), findsOneWidget);

      // Simulate user granting all permissions (both locationAlways and
      // notification must be granted for geofencingReady == true).
      fakeSvc.status = PermissionStatus.granted;

      // Invalidate the cached summary so the FutureProvider re-runs with
      // the new service state (this is exactly what the onFinished callback
      // in home_page.dart does via ref.invalidate).
      container.invalidate(permissionSummaryProvider);
      await _flushStream(tester);

      // Banner must be gone.
      expect(find.byType(PermissionBanner), findsNothing);
    } finally {
      await _teardown(tester);
    }
  });
}
