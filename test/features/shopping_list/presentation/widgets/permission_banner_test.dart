import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/features/shopping_list/presentation/permission_status_provider.dart';
import 'package:daijo/features/shopping_list/presentation/widgets/permission_banner.dart';

void main() {
  test('geofencingReady true only when always granted and notification ok', () {
    expect(
      const PermissionSummary(
        always: PermissionStatus.granted,
        notification: PermissionStatus.granted,
      ).geofencingReady,
      isTrue,
    );
    expect(
      const PermissionSummary(
        always: PermissionStatus.granted,
        notification: PermissionStatus.notApplicable,
      ).geofencingReady,
      isTrue,
    );
    expect(
      const PermissionSummary(
        always: PermissionStatus.denied,
        notification: PermissionStatus.granted,
      ).geofencingReady,
      isFalse,
    );
    expect(
      const PermissionSummary(
        always: PermissionStatus.granted,
        notification: PermissionStatus.denied,
      ).geofencingReady,
      isFalse,
    );
  });

  testWidgets('banner renders message and fires onTap', (t) async {
    var tapped = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: PermissionBanner(onTap: () => tapped++)),
    ));
    expect(find.textContaining('알림이 꺼져 있어요'), findsOneWidget);
    await t.tap(find.byType(PermissionBanner));
    expect(tapped, 1);
  });
}
