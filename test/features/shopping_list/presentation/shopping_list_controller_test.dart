import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/domain/entities/shopping_item.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    // Keep the StreamProvider alive so its underlying Drift stream stays open.
    container.listen(shoppingItemsProvider, (_, __) {});
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  /// Performs [action] and returns the next emission from [shoppingItemsProvider]
  /// that arrives after [action] completes.
  Future<List<ShoppingItem>> mutateAndAwait(
    ProviderContainer container,
    Future<void> Function() action,
  ) async {
    final completer = Completer<List<ShoppingItem>>();
    late ProviderSubscription<AsyncValue<List<ShoppingItem>>> sub;
    sub = container.listen(shoppingItemsProvider, (_, next) {
      if (!completer.isCompleted) {
        next.whenData((items) {
          completer.complete(items);
          sub.close();
        });
      }
    }, fireImmediately: false);
    await action();
    return completer.future;
  }

  test('add then stream emits the new item', () async {
    final items = await mutateAndAwait(
      container,
      () => container.read(shoppingListControllerProvider).add('수세미'),
    );
    expect(items.single.name, '수세미');
  });

  test('toggleDone updates the item and reorders it last', () async {
    final c = container.read(shoppingListControllerProvider);

    await mutateAndAwait(container, () => c.add('A'));
    final afterAddB = await mutateAndAwait(container, () => c.add('B'));
    final aId = afterAddB.first.id;

    final names = (await mutateAndAwait(
      container,
      () => c.toggleDone(aId, true),
    )).map((e) => e.name);
    expect(names, ['B', 'A']);
  });

  test('delete removes the item', () async {
    final c = container.read(shoppingListControllerProvider);

    final afterAdd = await mutateAndAwait(container, () => c.add('A'));
    final id = afterAdd.single.id;

    final afterDelete = await mutateAndAwait(container, () => c.delete(id));
    expect(afterDelete, isEmpty);
  });
}
