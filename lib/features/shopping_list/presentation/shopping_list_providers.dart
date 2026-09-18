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
