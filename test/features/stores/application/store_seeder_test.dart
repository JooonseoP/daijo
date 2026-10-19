import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/stores/application/store_seeder.dart';
import 'package:daijo/features/stores/data/datasources/store_local_datasource.dart';
import 'package:daijo/features/stores/data/datasources/store_seed_loader.dart';
import 'package:daijo/features/stores/data/repositories/store_repository_impl.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.data);
  String data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(data);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

String _json(List<String> ids) => jsonEncode([
      for (final id in ids)
        {'id': id, 'name': 's$id', 'latitude': 37.5, 'longitude': 127.0}
    ]);

void main() {
  late AppDatabase db;
  late StoreRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StoreRepositoryImpl(StoreLocalDataSource(db));
  });
  tearDown(() => db.close());

  StoreSeeder seeder(_FakeBundle bundle) => StoreSeeder(
        loader: StoreSeedLoader(bundle),
        repository: repo,
        db: db,
      );

  test('first run loads stores and records version', () async {
    await seeder(_FakeBundle(_json(['1', '2']))).ensureSeeded();
    expect((await repo.getAll()).length, 2);
    expect(await db.getSetting('stores_seed_version'), kStoresSeedVersion);
  });

  test('second run with same version skips reload', () async {
    final bundle = _FakeBundle(_json(['1', '2']));
    await seeder(bundle).ensureSeeded();
    bundle.data = _json(['9']); // changed asset, but version unchanged
    await seeder(bundle).ensureSeeded();
    expect((await repo.getAll()).map((s) => s.id).toSet(), {'1', '2'});
  });

  test('malformed JSON degrades: no crash, no version recorded', () async {
    await seeder(_FakeBundle('not json')).ensureSeeded();
    expect(await repo.getAll(), isEmpty);
    expect(await db.getSetting('stores_seed_version'), isNull);
  });
}
