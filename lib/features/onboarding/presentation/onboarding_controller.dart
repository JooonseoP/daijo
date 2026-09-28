import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_service.dart';
import '../domain/repositories/onboarding_preferences.dart';

class OnboardingState {
  const OnboardingState({
    this.whenInUse = PermissionStatus.denied,
    this.always = PermissionStatus.denied,
    this.notification = PermissionStatus.denied,
  });

  final PermissionStatus whenInUse;
  final PermissionStatus always;
  final PermissionStatus notification;

  bool get alwaysUnlocked => whenInUse == PermissionStatus.granted;

  OnboardingState copyWith({
    PermissionStatus? whenInUse,
    PermissionStatus? always,
    PermissionStatus? notification,
  }) {
    return OnboardingState(
      whenInUse: whenInUse ?? this.whenInUse,
      always: always ?? this.always,
      notification: notification ?? this.notification,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this._permissions, this._prefs)
      : super(const OnboardingState());

  final PermissionService _permissions;
  final OnboardingPreferences _prefs;

  Future<void> refresh() async {
    final whenInUse =
        await _permissions.check(PermissionKind.locationWhenInUse);
    final always = await _permissions.check(PermissionKind.locationAlways);
    final notification =
        await _permissions.check(PermissionKind.notification);
    state = OnboardingState(
      whenInUse: whenInUse,
      always: always,
      notification: notification,
    );
  }

  Future<void> requestWhenInUse() async {
    final status =
        await _permissions.request(PermissionKind.locationWhenInUse);
    state = state.copyWith(whenInUse: status);
  }

  Future<void> requestAlways() async {
    if (!state.alwaysUnlocked) return;
    final status = await _permissions.request(PermissionKind.locationAlways);
    state = state.copyWith(always: status);
  }

  Future<void> requestNotification() async {
    final status = await _permissions.request(PermissionKind.notification);
    // Android will not re-prompt a notification permission the user already
    // decided (e.g. granted then revoked in settings): request() returns denied
    // without a dialog. Route to app settings so re-enabling is possible.
    if (status != PermissionStatus.granted) {
      await _permissions.openAppSettings();
    }
    state = state.copyWith(notification: status);
  }

  Future<void> openSettings() => _permissions.openAppSettings();

  Future<void> complete() => _prefs.setCompleted();
}
