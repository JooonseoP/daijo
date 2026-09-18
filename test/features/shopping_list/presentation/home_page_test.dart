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
}
