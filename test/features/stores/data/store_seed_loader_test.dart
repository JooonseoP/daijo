import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/stores/data/datasources/store_seed_loader.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._data);
  final String _data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(_data);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

void main() {
  test('parses JSON array into stores with default radius and string id', () async {
    const json = '''
    [
      {"id":"12638299","name":"다이소 강남역2호점","address":"서울","latitude":37.498793,"longitude":127.028934,"phone":"1522-4400"}
    ]''';
    final loader = StoreSeedLoader(_FakeBundle(json));
    final stores = await loader.load();
    expect(stores.single.id, '12638299');
    expect(stores.single.name, '다이소 강남역2호점');
    expect(stores.single.latitude, 37.498793);
    expect(stores.single.radius, 150.0);
  });

  test('throws on malformed JSON', () async {
    final loader = StoreSeedLoader(_FakeBundle('not json'));
    expect(loader.load(), throwsA(anything));
  });
}
