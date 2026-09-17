import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/data/datasources/shopping_item_local_datasource.dart';

void main() {
  late AppDatabase db;
  late ShoppingItemLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = ShoppingItemLocalDataSource(db);
  });
  tearDown(() => db.close());

  test('insert stores name with default quantity 1 and not done', () async {
    final id = await ds.insert('건전지');
    final row = (await ds.watchAll().first).single;
    expect(row.id, id);
    expect(row.name, '건전지');
    expect(row.quantity, 1);
    expect(row.isDone, isFalse);
  });

  test('watchAll orders incomplete before done, each by createdAt', () async {
    final a = await ds.insert('A'); // oldest
    // ignore: unused_local_variable
    final b = await ds.insert('B');
    // ignore: unused_local_variable
    final c = await ds.insert('C');
    await ds.updateDone(a, true); // A done → should sink to bottom

    final names = (await ds.watchAll().first).map((r) => r.name).toList();
    expect(names, ['B', 'C', 'A']);
  });

  test('updateName / updateQuantity / updateDone mutate the row', () async {
    final id = await ds.insert('X');
    await ds.updateName(id, 'Y');
    await ds.updateQuantity(id, 4);
    await ds.updateDone(id, true);
    final row = (await ds.watchAll().first).single;
    expect(row.name, 'Y');
    expect(row.quantity, 4);
    expect(row.isDone, isTrue);
  });

  test('deleteById removes the row', () async {
    final id = await ds.insert('X');
    await ds.deleteById(id);
    expect(await ds.watchAll().first, isEmpty);
  });
}
