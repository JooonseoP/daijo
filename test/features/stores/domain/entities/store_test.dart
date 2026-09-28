import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/stores/domain/entities/store.dart';

Store _store({String id = '1'}) => Store(
      id: id,
      name: '다이소 강남역점',
      latitude: 37.5,
      longitude: 127.0,
      radius: 150,
    );

void main() {
  test('Store equality by value', () {
    expect(_store(), _store());
    expect(_store().hashCode, _store().hashCode);
    expect(_store(id: '1'), isNot(_store(id: '2')));
  });
}
