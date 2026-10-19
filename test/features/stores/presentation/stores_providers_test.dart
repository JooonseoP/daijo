// test/features/stores/presentation/stores_providers_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:daijo/features/stores/domain/entities/store.dart';
import 'package:daijo/features/stores/presentation/stores_providers.dart';

class _FakeLocation implements LocationService {
  _FakeLocation(this._pos);
  final LatLng? _pos;
  @override
  Future<LatLng?> currentPosition() async => _pos;
}

Store _s(String id, double lng) =>
    Store(id: id, name: 's$id', latitude: 0, longitude: lng, radius: 150);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer containerWith(LocationService loc) => ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          locationServiceProvider.overrideWithValue(loc),
        ],
      );

  test('nearbySelectionProvider selects nearest stores at current position',
      () async {
    final c = containerWith(_FakeLocation(const LatLng(0, 0)));
    addTearDown(c.dispose);
    await c.read(storeRepositoryProvider).replaceAll([_s('far', 3), _s('near', 1)]);

    final selection = await c.read(nearbySelectionProvider.future);
    expect(selection.stores.first.id, 'near');
  });

  test('nearbySelectionProvider returns empty when location is null', () async {
    final c = containerWith(_FakeLocation(null));
    addTearDown(c.dispose);
    await c.read(storeRepositoryProvider).replaceAll([_s('a', 1)]);

    final selection = await c.read(nearbySelectionProvider.future);
    expect(selection.stores, isEmpty);
  });
}
