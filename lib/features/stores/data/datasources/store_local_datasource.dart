import '../../../../core/database/app_database.dart';
import '../../domain/entities/store.dart';
import '../mappers/store_mapper.dart';

class StoreLocalDataSource {
  StoreLocalDataSource(this._db);

  final AppDatabase _db;

  Future<List<StoreRow>> getAll() => _db.select(_db.stores).get();

  Future<void> replaceAll(List<Store> stores) {
    return _db.transaction(() async {
      await _db.delete(_db.stores).go();
      await _db.batch((b) {
        b.insertAll(_db.stores, stores.map(storeToCompanion).toList());
      });
    });
  }

  Future<void> clear() => _db.delete(_db.stores).go();
}
