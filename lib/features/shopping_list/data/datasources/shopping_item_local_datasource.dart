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
            (t) => OrderingTerm(expression: t.id),
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
