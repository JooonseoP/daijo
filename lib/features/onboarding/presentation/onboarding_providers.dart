import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_providers.dart';
import '../../shopping_list/presentation/shopping_list_providers.dart';
import '../data/repositories/onboarding_preferences_impl.dart';
import '../domain/repositories/onboarding_preferences.dart';
import 'onboarding_controller.dart';

final onboardingPreferencesProvider = Provider<OnboardingPreferences>((ref) {
  return DriftOnboardingPreferences(ref.watch(appDatabaseProvider));
});

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController(
    ref.watch(permissionServiceProvider),
    ref.watch(onboardingPreferencesProvider),
  );
});
