import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/core/permissions/permission_service.dart';
import 'package:daijo/core/permissions/permission_providers.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_controller.dart';
import 'package:daijo/features/onboarding/presentation/onboarding_providers.dart';
import 'package:daijo/features/shopping_list/presentation/shopping_list_providers.dart';

/// Configurable fake: returns queued statuses and records requests.
class FakePermissionService implements PermissionService {
  final Map<PermissionKind, PermissionStatus> checkResult = {
    PermissionKind.locationWhenInUse: PermissionStatus.denied,
    PermissionKind.locationAlways: PermissionStatus.denied,
    PermissionKind.notification: PermissionStatus.denied,
  };
  final Map<PermissionKind, PermissionStatus> requestResult = {};
  final List<PermissionKind> requested = [];
  int openSettingsCount = 0;

  @override
  Future<PermissionStatus> check(PermissionKind kind) async => checkResult[kind]!;

  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    requested.add(kind);
    return requestResult[kind] ?? checkResult[kind]!;
  }

  @override
  Future<void> openAppSettings() async => openSettingsCount++;
}

void main() {
  late AppDatabase db;
  late FakePermissionService svc;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = FakePermissionService();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      permissionServiceProvider.overrideWithValue(svc),
    ]);
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);

  test('refresh loads current statuses into state', () async {
    svc.checkResult[PermissionKind.locationWhenInUse] = PermissionStatus.granted;
    await controller().refresh();
    final s = container.read(onboardingControllerProvider);
    expect(s.whenInUse, PermissionStatus.granted);
    expect(s.always, PermissionStatus.denied);
  });

  test('alwaysUnlocked is false until whenInUse granted', () {
    expect(container.read(onboardingControllerProvider).alwaysUnlocked, isFalse);
  });

  test('requestAlways is a no-op while locked', () async {
    await controller().requestAlways();
    expect(svc.requested, isEmpty);
  });

  test('requestAlways proceeds once whenInUse granted', () async {
    svc.requestResult[PermissionKind.locationWhenInUse] = PermissionStatus.granted;
    await controller().requestWhenInUse();
    svc.requestResult[PermissionKind.locationAlways] = PermissionStatus.granted;
    await controller().requestAlways();
    expect(svc.requested,
        [PermissionKind.locationWhenInUse, PermissionKind.locationAlways]);
    expect(container.read(onboardingControllerProvider).always,
        PermissionStatus.granted);
  });

  test('complete persists the onboarding flag', () async {
    await controller().complete();
    final prefs = container.read(onboardingPreferencesProvider);
    expect(await prefs.isCompleted(), isTrue);
  });
}
