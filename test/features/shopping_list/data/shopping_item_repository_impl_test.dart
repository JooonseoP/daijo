import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/data/datasources/shopping_item_local_datasource.dart';
import 'package:daijo/features/shopping_list/data/repositories/shopping_item_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ShoppingItemRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ShoppingItemRepositoryImpl(ShoppingItemLocalDataSource(db));
  });
  tearDown(() => db.close());

  test('add inserts a domain entity with quantity 1', () async {
    await repo.add('수세미');
    final items = await repo.watchAll().first;
    expect(items.single.name, '수세미');
    expect(items.single.quantity, 1);
    expect(items.single.isDone, isFalse);
  });

  test('add ignores blank names after trim', () async {
    await repo.add('   ');
    expect(await repo.watchAll().first, isEmpty);
  });

  test('add trims surrounding whitespace', () async {
    await repo.add('  건전지  ');
    expect((await repo.watchAll().first).single.name, '건전지');
  });

  test('setQuantity clamps values below 1 up to 1', () async {
    await repo.add('X');
    final id = (await repo.watchAll().first).single.id;
    await repo.setQuantity(id, 0);
    expect((await repo.watchAll().first).single.quantity, 1);
  });

  test('setDone and delete work end to end', () async {
    await repo.add('X');
    final id = (await repo.watchAll().first).single.id;
    await repo.setDone(id, true);
    expect((await repo.watchAll().first).single.isDone, isTrue);
    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
  });
}
