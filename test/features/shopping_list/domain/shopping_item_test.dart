import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/domain/entities/shopping_item.dart';

void main() {
  final createdAt = DateTime(2026, 9, 17);

  ShoppingItem base() => ShoppingItem(
        id: 1,
        name: '수세미',
        quantity: 2,
        isDone: false,
        createdAt: createdAt,
      );

  test('value equality holds for identical field values', () {
    expect(base(), equals(base()));
    expect(base().hashCode, base().hashCode);
  });

  test('copyWith overrides only the given fields', () {
    final done = base().copyWith(isDone: true, quantity: 5);
    expect(done.isDone, isTrue);
    expect(done.quantity, 5);
    expect(done.name, '수세미');
    expect(done.id, 1);
  });
}
