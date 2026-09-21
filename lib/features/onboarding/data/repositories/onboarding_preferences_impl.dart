import '../../../../core/database/app_database.dart';
import '../../domain/repositories/onboarding_preferences.dart';

class DriftOnboardingPreferences implements OnboardingPreferences {
  DriftOnboardingPreferences(this._db);

  final AppDatabase _db;
  static const _key = 'onboarding_completed';

  @override
  Future<bool> isCompleted() async => await _db.getSetting(_key) == 'true';

  @override
  Future<void> setCompleted() => _db.setSetting(_key, 'true');
}
