import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/location/location_service.dart';

void main() {
  test('LatLng equality and hashCode by value', () {
    expect(const LatLng(37.5, 127.0), const LatLng(37.5, 127.0));
    expect(const LatLng(37.5, 127.0).hashCode,
        const LatLng(37.5, 127.0).hashCode);
    expect(const LatLng(37.5, 127.0), isNot(const LatLng(37.5, 127.1)));
  });
}
