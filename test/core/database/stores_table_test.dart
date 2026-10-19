import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';

void main() {
  test('stores table stores and reads a row; schemaVersion is 3', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 3);

    await db.into(db.stores).insert(const StoresCompanion(
          id: Value('42'),
          name: Value('다이소 강남역점'),
          latitude: Value(37.5),
          longitude: Value(127.0),
          radius: Value(150.0),
        ));
    final rows = await db.select(db.stores).get();
    expect(rows.single.id, '42');
    expect(rows.single.radius, 150.0);
  });
}
