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
