class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.isDone,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int quantity;
  final bool isDone;
  final DateTime createdAt;

  ShoppingItem copyWith({
    int? id,
    String? name,
    int? quantity,
    bool? isDone,
    DateTime? createdAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShoppingItem &&
      other.id == id &&
      other.name == name &&
      other.quantity == quantity &&
      other.isDone == isDone &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, quantity, isDone, createdAt);
}
