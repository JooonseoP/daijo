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

/// HomePage watches [shoppingItemsProvider], a StreamProvider backed by Drift's
/// live `.watch()`. That stream never lets `pumpAndSettle()` settle under
/// FakeAsync (the real DB does async work the fake clock never advances), and at
/// disposal Drift schedules a `Timer(Duration.zero)` that trips the pending-timer
/// invariant. So we drive the UI with explicit bounded pumps and let any
/// DB-affecting interaction run under [WidgetTester.runAsync] so the real stream
/// can emit, then rebuild the widget with a plain pump outside runAsync.
Future<void> _flushStream(WidgetTester tester) async {
  // Let the real (non-fake) async Drift stream emit, then rebuild the tree.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

/// Unmounts the ProviderScope so Drift's disposal `Timer(Duration.zero)` is
/// scheduled, then advances the fake clock so that timer fires before the
/// test's end-of-test `_verifyInvariants` pending-timer check runs. The
/// disposal timer is created inside the FakeAsync zone, so it is cleared by
/// pumping the fake clock forward — not by real async.
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
    await tester.pumpWidget(_app(db));
    await _flushStream(tester);

    expect(find.textContaining('살 물건을 추가하세요'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('adding via the field shows the item', (tester) async {
    await tester.pumpWidget(_app(db));
    await _flushStream(tester);

    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), '수세미');
      await tester.testTextInput.receiveAction(TextInputAction.done);
    });
    await _flushStream(tester);

    expect(find.text('수세미'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('completing an item shows the 완료 divider', (tester) async {
    await tester.pumpWidget(_app(db));
    await _flushStream(tester);

    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), '건전지');
      await tester.testTextInput.receiveAction(TextInputAction.done);
    });
    await _flushStream(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byType(Checkbox).first);
    });
    await _flushStream(tester);

    expect(find.text('완료'), findsOneWidget);

    await _teardown(tester);
  });
}
