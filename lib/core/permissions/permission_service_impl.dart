import 'package:permission_handler/permission_handler.dart' as ph;

import 'permission_service.dart';

class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  ph.Permission _map(PermissionKind kind) {
    switch (kind) {
      case PermissionKind.locationWhenInUse:
        return ph.Permission.locationWhenInUse;
      case PermissionKind.locationAlways:
        return ph.Permission.locationAlways;
      case PermissionKind.notification:
        return ph.Permission.notification;
    }
  }

  PermissionStatus _status(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermissionStatus.granted;
    if (s.isPermanentlyDenied) return PermissionStatus.permanentlyDenied;
    if (s.isRestricted) return PermissionStatus.notApplicable;
    return PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> check(PermissionKind kind) async {
    return _status(await _map(kind).status);
  }

  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    return _status(await _map(kind).request());
  }

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}
