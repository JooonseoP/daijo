class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// 현재 위치 취득 인터페이스. 실구현(geolocator)은 다음 슬라이스에서 제공한다.
abstract class LocationService {
  /// 실패/권한 없음 시 null.
  Future<LatLng?> currentPosition();
}
