import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/features/onboarding/presentation/widgets/permission_step_tile.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('denied shows request button and fires onRequest', (t) async {
    var tapped = 0;
    await t.pumpWidget(_host(PermissionStepTile(
      title: '위치 (앱 사용 중)',
      description: '가까운 매장을 찾기 위해 필요해요.',
      icon: Icons.location_on,
      status: PermissionStatus.denied,
      onRequest: () => tapped++,
    )));
    expect(find.text('위치 (앱 사용 중)'), findsOneWidget);
    await t.tap(find.text('허용'));
    expect(tapped, 1);
  });

  testWidgets('granted shows granted mark and no request button', (t) async {
    await t.pumpWidget(_host(PermissionStepTile(
      title: '알림',
      description: '목록 알림을 위해 필요해요.',
      icon: Icons.notifications,
      status: PermissionStatus.granted,
      onRequest: () {},
    )));
    expect(find.text('허용됨'), findsOneWidget);
    expect(find.text('허용'), findsNothing);
  });

  testWidgets('locked shows lock text and no button', (t) async {
    await t.pumpWidget(_host(PermissionStepTile(
      title: '위치 항상 허용',
      description: '백그라운드 감지에 필요해요.',
      icon: Icons.my_location,
      status: PermissionStatus.denied,
      locked: true,
      onRequest: () {},
    )));
    expect(find.textContaining('잠김'), findsOneWidget);
    expect(find.text('허용'), findsNothing);
    expect(find.text('설정에서 허용'), findsNothing);
  });

  testWidgets('permanentlyDenied shows open-settings button', (t) async {
    var opened = 0;
    await t.pumpWidget(_host(PermissionStepTile(
      title: '알림',
      description: '목록 알림을 위해 필요해요.',
      icon: Icons.notifications,
      status: PermissionStatus.permanentlyDenied,
      onOpenSettings: () => opened++,
    )));
    await t.tap(find.text('설정 열기'));
    expect(opened, 1);
  });

  testWidgets('disclosure text is shown when provided', (t) async {
    await t.pumpWidget(_host(PermissionStepTile(
      title: '위치 항상 허용',
      description: '백그라운드 감지에 필요해요.',
      icon: Icons.my_location,
      status: PermissionStatus.denied,
      disclosure: '백그라운드에서 기기 위치를 확인합니다.',
      onRequest: () {},
    )));
    expect(find.textContaining('백그라운드에서 기기 위치'), findsOneWidget);
    expect(find.text('설정에서 허용'), findsOneWidget);
  });
}
