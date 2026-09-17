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
