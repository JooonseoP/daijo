enum PermissionKind { locationWhenInUse, locationAlways, notification }

enum PermissionStatus { granted, denied, permanentlyDenied, notApplicable }

abstract interface class PermissionService {
  Future<PermissionStatus> check(PermissionKind kind);
  Future<PermissionStatus> request(PermissionKind kind);
  Future<void> openAppSettings();
}
