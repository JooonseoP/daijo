import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/core/database/app_database.dart';
import 'package:daijo/features/shopping_list/data/mappers/shopping_item_mapper.dart';

void main() {
  test('maps a Drift row to a domain entity field-for-field', () {
    final row = ShoppingItemRow(
      id: 7,
      name: '물티슈',
      quantity: 3,
      isDone: true,
      createdAt: DateTime(2026, 9, 17),
    );

    final entity = toEntity(row);

    expect(entity.id, 7);
    expect(entity.name, '물티슈');
    expect(entity.quantity, 3);
    expect(entity.isDone, isTrue);
    expect(entity.createdAt, DateTime(2026, 9, 17));
  });
}
