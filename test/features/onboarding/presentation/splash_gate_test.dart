import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/core/permissions/permission_providers.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_page.dart';
import 'package:daijo/features/onboarding/presentation/splash_gate.dart';
import 'package:daijo/features/shopping_list/presentation/home_page.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

class GrantedPermissionService implements PermissionService {
  @override
  Future<PermissionStatus> check(PermissionKind kind) async =>
      PermissionStatus.granted;
  @override
  Future<PermissionStatus> request(PermissionKind kind) async =>
      PermissionStatus.granted;
  @override
  Future<void> openAppSettings() async {}
}

/// Unmounts the tree and flushes Drift's zero-duration disposal timer so no
/// pending timer is left at the end of the test.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        permissionServiceProvider.overrideWithValue(GrantedPermissionService()),
      ],
      // Zero-duration intro so the gate resolves immediately in tests.
      child: const MaterialApp(home: SplashGate(introDuration: Duration.zero)),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('first launch (flag unset) routes to OnboardingPage', (t) async {
    await pump(t);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('completed flag routes straight to HomePage', (t) async {
    try {
      await db.setSetting('onboarding_completed', 'true');
      await pump(t);
      expect(find.byType(HomePage), findsOneWidget);
    } finally {
      await _teardown(t);
    }
  });
}
