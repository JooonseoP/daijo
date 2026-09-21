import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/onboarding/data/repositories/onboarding_preferences_impl.dart';

void main() {
  late AppDatabase db;
  late DriftOnboardingPreferences prefs;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    prefs = DriftOnboardingPreferences(db);
  });
  tearDown(() => db.close());

  test('isCompleted is false before setCompleted', () async {
    expect(await prefs.isCompleted(), isFalse);
  });

  test('isCompleted is true after setCompleted', () async {
    await prefs.setCompleted();
    expect(await prefs.isCompleted(), isTrue);
  });

  test('setCompleted is idempotent', () async {
    await prefs.setCompleted();
    await prefs.setCompleted();
    expect(await prefs.isCompleted(), isTrue);
  });
}
