import '../../../../core/location/location_service.dart';
import 'store.dart';

class GeofenceSelection {
  const GeofenceSelection({
    required this.center,
    required this.stores,
    required this.boundaryRadiusMeters,
  });

  const GeofenceSelection.empty()
      : center = const LatLng(0, 0),
        stores = const [],
        boundaryRadiusMeters = 0;

  final LatLng center;
  final List<Store> stores;
  final double boundaryRadiusMeters;
}
