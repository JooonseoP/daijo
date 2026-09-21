import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_providers.dart';
import '../../../core/permissions/permission_service.dart';

class PermissionSummary {
  const PermissionSummary({required this.always, required this.notification});

  final PermissionStatus always;
  final PermissionStatus notification;

  bool get geofencingReady =>
      always == PermissionStatus.granted &&
      (notification == PermissionStatus.granted ||
          notification == PermissionStatus.notApplicable);
}

final permissionSummaryProvider = FutureProvider<PermissionSummary>((ref) async {
  final svc = ref.watch(permissionServiceProvider);
  return PermissionSummary(
    always: await svc.check(PermissionKind.locationAlways),
    notification: await svc.check(PermissionKind.notification),
  );
});
