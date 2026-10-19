import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/features/stores/application/nearby_selector.dart';
import 'package:daijo/features/stores/domain/entities/store.dart';

Store _s(String id, double lat, double lng) =>
    Store(id: id, name: 'store-$id', latitude: lat, longitude: lng, radius: 150);

void main() {
  const center = LatLng(0, 0);

  test('sorts by distance and caps at n', () {
    final stores = [
      _s('far', 0, 3),
      _s('near', 0, 1),
      _s('mid', 0, 2),
    ];
    final result = NearbySelector.select(center, stores, n: 2);
    expect(result.stores.map((s) => s.id).toList(), ['near', 'mid']);
  });

  test('boundary radius equals distance to farthest selected store', () {
    final stores = [_s('a', 0, 1), _s('b', 0, 2)];
    final result = NearbySelector.select(center, stores, n: 2);
    expect(result.boundaryRadiusMeters,
        closeTo(haversineMeters(center, const LatLng(0, 2)), 1e-6));
  });

  test('ties broken by id ascending', () {
    final stores = [_s('b', 0, 1), _s('a', 0, 1)];
    final result = NearbySelector.select(center, stores, n: 1);
    expect(result.stores.single.id, 'a');
  });

  test('fewer stores than n selects all', () {
    final result = NearbySelector.select(center, [_s('a', 0, 1)], n: 20);
    expect(result.stores.length, 1);
    expect(result.boundaryRadiusMeters,
        closeTo(haversineMeters(center, const LatLng(0, 1)), 1e-6));
  });

  test('empty store list yields empty selection with zero radius', () {
    final result = NearbySelector.select(center, [], n: 20);
    expect(result.stores, isEmpty);
    expect(result.boundaryRadiusMeters, 0);
  });
}
