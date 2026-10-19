import '../../domain/entities/store.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_local_datasource.dart';
import '../mappers/store_mapper.dart';

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl(this._ds);

  final StoreLocalDataSource _ds;

  @override
  Future<List<Store>> getAll() async =>
      (await _ds.getAll()).map(storeFromRow).toList();

  @override
  Future<void> replaceAll(List<Store> stores) => _ds.replaceAll(stores);

  @override
  Future<void> clear() => _ds.clear();
}
