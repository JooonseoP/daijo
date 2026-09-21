import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema version is 2', () {
    expect(db.schemaVersion, 2);
  });

  test('getSetting returns null for missing key', () async {
    expect(await db.getSetting('missing'), isNull);
  });

  test('setSetting then getSetting returns the value', () async {
    await db.setSetting('onboarding_completed', 'true');
    expect(await db.getSetting('onboarding_completed'), 'true');
  });

  test('setSetting upserts (idempotent) on same key', () async {
    await db.setSetting('k', 'a');
    await db.setSetting('k', 'b');
    expect(await db.getSetting('k'), 'b');
    final rows = await db.select(db.appSettings).get();
    expect(rows.length, 1);
  });
}
