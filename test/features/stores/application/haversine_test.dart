import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/location/location_service.dart';
import 'package:daijo/features/stores/application/nearby_selector.dart';

void main() {
  test('1 degree of latitude at equator ~= 111194.9 m', () {
    final d = haversineMeters(const LatLng(0, 0), const LatLng(1, 0));
    expect(d, closeTo(111194.9, 1.0));
  });

  test('same point is zero distance', () {
    expect(haversineMeters(const LatLng(37.5, 127.0), const LatLng(37.5, 127.0)),
        closeTo(0, 1e-6));
  });
}
