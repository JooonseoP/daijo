abstract interface class OnboardingPreferences {
  Future<bool> isCompleted();
  Future<void> setCompleted();
}
