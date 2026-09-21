import 'package:flutter/foundation.dart';
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
    try {
      return _status(await _map(kind).status);
    } catch (e) {
      debugPrint('[PermissionHandlerService] check($kind) failed: $e');
      return PermissionStatus.denied;
    }
  }

  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    try {
      return _status(await _map(kind).request());
    } catch (e) {
      debugPrint('[PermissionHandlerService] request($kind) failed: $e');
      return PermissionStatus.denied;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await ph.openAppSettings();
    } catch (e) {
      debugPrint('[PermissionHandlerService] openAppSettings() failed: $e');
    }
  }
}
