import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/stores/data/datasources/store_local_datasource.dart';
import 'package:daijo/features/stores/data/repositories/store_repository_impl.dart';
import 'package:daijo/features/stores/domain/entities/store.dart';

Store _s(String id) =>
    Store(id: id, name: 'store-$id', latitude: 37.5, longitude: 127.0, radius: 150);

void main() {
  late AppDatabase db;
  late StoreRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StoreRepositoryImpl(StoreLocalDataSource(db));
  });
  tearDown(() => db.close());

  test('replaceAll then getAll round-trips stores', () async {
    await repo.replaceAll([_s('1'), _s('2')]);
    final all = await repo.getAll();
    expect(all.map((s) => s.id).toSet(), {'1', '2'});
  });

  test('replaceAll clears previous rows first', () async {
    await repo.replaceAll([_s('1'), _s('2')]);
    await repo.replaceAll([_s('3')]);
    final all = await repo.getAll();
    expect(all.map((s) => s.id).toList(), ['3']);
  });

  test('clear empties the table', () async {
    await repo.replaceAll([_s('1')]);
    await repo.clear();
    expect(await repo.getAll(), isEmpty);
  });
}
