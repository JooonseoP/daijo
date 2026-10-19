import 'dart:math' as math;

import '../../../core/location/location_service.dart';
import '../domain/entities/geofence_selection.dart';
import '../domain/entities/store.dart';

const double kEarthRadiusMeters = 6371000.0;
const int kNearbyStoreCount = 20;

double haversineMeters(LatLng a, LatLng b) {
  final lat1 = _toRad(a.latitude);
  final lat2 = _toRad(b.latitude);
  final dLat = _toRad(b.latitude - a.latitude);
  final dLng = _toRad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * kEarthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
}

double _toRad(double deg) => deg * math.pi / 180.0;

abstract final class NearbySelector {
  static GeofenceSelection select(
    LatLng center,
    List<Store> stores, {
    int n = kNearbyStoreCount,
  }) {
    if (stores.isEmpty) {
      return GeofenceSelection(center: center, stores: const [], boundaryRadiusMeters: 0);
    }
    final withDistance = stores
        .map((s) => (
              store: s,
              distance: haversineMeters(center, LatLng(s.latitude, s.longitude)),
            ))
        .toList()
      ..sort((a, b) {
        final byDistance = a.distance.compareTo(b.distance);
        return byDistance != 0 ? byDistance : a.store.id.compareTo(b.store.id);
      });
    final selected = withDistance.take(n).toList();
    if (selected.isEmpty) {
      return GeofenceSelection(center: center, stores: const [], boundaryRadiusMeters: 0);
    }
    return GeofenceSelection(
      center: center,
      stores: selected.map((e) => e.store).toList(),
      boundaryRadiusMeters: selected.last.distance,
    );
  }
}
