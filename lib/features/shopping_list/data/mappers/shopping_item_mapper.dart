import '../../../../core/database/app_database.dart';
import '../../domain/entities/shopping_item.dart';

ShoppingItem toEntity(ShoppingItemRow row) => ShoppingItem(
      id: row.id,
      name: row.name,
      quantity: row.quantity,
      isDone: row.isDone,
      createdAt: row.createdAt,
    );
