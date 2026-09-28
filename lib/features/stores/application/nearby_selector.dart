import 'dart:math' as math;

import '../../../core/location/location_service.dart';

const double kEarthRadiusMeters = 6371000.0;

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
