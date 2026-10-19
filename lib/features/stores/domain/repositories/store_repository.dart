import '../entities/store.dart';

abstract class StoreRepository {
  Future<List<Store>> getAll();
  Future<void> replaceAll(List<Store> stores);
  Future<void> clear();
}
