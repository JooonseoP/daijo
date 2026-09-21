import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/core/permissions/permission_providers.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_page.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

class FakePermissionService implements PermissionService {
  final Map<PermissionKind, PermissionStatus> result = {
    PermissionKind.locationWhenInUse: PermissionStatus.denied,
    PermissionKind.locationAlways: PermissionStatus.denied,
    PermissionKind.notification: PermissionStatus.denied,
  };
  @override
  Future<PermissionStatus> check(PermissionKind kind) async => result[kind]!;
  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    result[kind] = PermissionStatus.granted;
    return PermissionStatus.granted;
  }
  @override
  Future<void> openAppSettings() async {}
}

void main() {
  late AppDatabase db;
  late FakePermissionService svc;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = FakePermissionService();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester t, {VoidCallback? onFinished}) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        permissionServiceProvider.overrideWithValue(svc),
      ],
      child: MaterialApp(home: OnboardingPage(onFinished: onFinished)),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('renders three permission steps and CTA', (t) async {
    await pump(t);
    expect(find.text('위치 (앱 사용 중)'), findsOneWidget);
    expect(find.text('위치 항상 허용'), findsOneWidget);
    expect(find.text('알림'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('always step is locked until whenInUse granted', (t) async {
    await pump(t);
    expect(find.textContaining('잠김'), findsOneWidget);
    // Grant whenInUse via its request button.
    await t.tap(find.text('허용').first);
    await t.pumpAndSettle();
    expect(find.textContaining('잠김'), findsNothing);
  });

  testWidgets('start button completes onboarding and calls onFinished', (t) async {
    var finished = 0;
    await pump(t, onFinished: () => finished++);
    await t.tap(find.text('시작하기'));
    await t.pumpAndSettle();
    expect(finished, 1);
    expect(await DriftPrefsProbe(db).completed(), isTrue);
  });

  testWidgets('skip also completes onboarding and calls onFinished', (t) async {
    var finished = 0;
    await pump(t, onFinished: () => finished++);
    await t.tap(find.text('권한 없이 목록만 사용할게요'));
    await t.pumpAndSettle();
    expect(finished, 1);
    expect(await DriftPrefsProbe(db).completed(), isTrue);
  });
}

/// Small probe to read the persisted flag without importing the impl class name
/// into assertions repeatedly.
class DriftPrefsProbe {
  DriftPrefsProbe(this.db);
  final AppDatabase db;
  Future<bool> completed() async =>
      await db.getSetting('onboarding_completed') == 'true';
}
