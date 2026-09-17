import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema version is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('shopping_items table starts empty', () async {
    expect(await db.select(db.shoppingItems).get(), isEmpty);
  });

  test('insert then read returns the row with defaults', () async {
    await db.into(db.shoppingItems).insert(
          ShoppingItemsCompanion.insert(name: '건전지', createdAt: DateTime(2026)),
        );
    final row = (await db.select(db.shoppingItems).get()).single;
    expect(row.name, '건전지');
    expect(row.quantity, 1);
    expect(row.isDone, isFalse);
  });
}
