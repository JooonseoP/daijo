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
  ShoppingListController(this._repo, this._ref);

  final ShoppingItemRepository _repo;
  final Ref _ref;

  Future<void> add(String name) async {
    if (name.trim().isEmpty) return;
    await _repo.add(name);
    _ref.invalidate(shoppingItemsProvider);
  }

  Future<void> rename(int id, String name) async {
    await _repo.rename(id, name);
    _ref.invalidate(shoppingItemsProvider);
  }

  Future<void> setQuantity(int id, int quantity) async {
    await _repo.setQuantity(id, quantity);
    _ref.invalidate(shoppingItemsProvider);
  }

  Future<void> toggleDone(int id, bool isDone) async {
    await _repo.setDone(id, isDone);
    _ref.invalidate(shoppingItemsProvider);
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    _ref.invalidate(shoppingItemsProvider);
  }
}

final shoppingListControllerProvider = Provider<ShoppingListController>(
  (ref) => ShoppingListController(
    ref.watch(shoppingItemRepositoryProvider),
    ref,
  ),
);
