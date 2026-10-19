import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../data/datasources/store_seed_loader.dart';
import '../domain/repositories/store_repository.dart';

const String kStoresSeedVersion = 'daiso-2026-09-17';
const String _versionKey = 'stores_seed_version';

class StoreSeeder {
  StoreSeeder({
    required StoreSeedLoader loader,
    required StoreRepository repository,
    required AppDatabase db,
  })  : _loader = loader,
        _repo = repository,
        _db = db;

  final StoreSeedLoader _loader;
  final StoreRepository _repo;
  final AppDatabase _db;

  Future<void> ensureSeeded() async {
    final current = await _db.getSetting(_versionKey);
    if (current == kStoresSeedVersion) return;
    try {
      final stores = await _loader.load();
      await _repo.replaceAll(stores);
      await _db.setSetting(_versionKey, kStoresSeedVersion);
    } catch (e) {
      debugPrint('[StoreSeeder] seed load failed, keeping existing data: $e');
    }
  }
}
