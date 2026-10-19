// lib/features/stores/presentation/stores_providers.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../shopping_list/presentation/shopping_list_providers.dart';
import '../application/nearby_selector.dart';
import '../application/store_seeder.dart';
import '../data/datasources/store_local_datasource.dart';
import '../data/datasources/store_seed_loader.dart';
import '../data/repositories/store_repository_impl.dart';
import '../domain/entities/geofence_selection.dart';
import '../domain/repositories/store_repository.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return StoreRepositoryImpl(StoreLocalDataSource(db));
});

final storeSeederProvider = Provider<StoreSeeder>((ref) {
  return StoreSeeder(
    loader: StoreSeedLoader(rootBundle),
    repository: ref.watch(storeRepositoryProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => throw UnimplementedError(
    'locationServiceProvider must be overridden',
  ),
);

final nearbySelectionProvider = FutureProvider<GeofenceSelection>((ref) async {
  final position = await ref.watch(locationServiceProvider).currentPosition();
  if (position == null) return const GeofenceSelection.empty();
  final stores = await ref.watch(storeRepositoryProvider).getAll();
  return NearbySelector.select(position, stores);
});
