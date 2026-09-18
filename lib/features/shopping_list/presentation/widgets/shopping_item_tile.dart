import 'package:flutter/material.dart';
import '../../domain/entities/shopping_item.dart';

class ShoppingItemTile extends StatefulWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onToggleDone,
    required this.onRename,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  final ShoppingItem item;
  final ValueChanged<bool> onToggleDone;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDelete;

  @override
  State<ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends State<ShoppingItemTile> {
  bool _editing = false;
  late final TextEditingController _controller =
      TextEditingController(text: widget.item.name);

  @override
  void didUpdateWidget(ShoppingItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.item.name != widget.item.name) {
      _controller.text = widget.item.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitRename() {
    final text = _controller.text.trim();
    setState(() => _editing = false);
    if (text.isNotEmpty && text != widget.item.name) {
      widget.onRename(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Dismissible(
      key: ValueKey('tile-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Checkbox(
          key: ValueKey('check-${item.id}'),
          value: item.isDone,
          onChanged: (v) => widget.onToggleDone(v ?? false),
        ),
        title: _editing
            ? TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitRename(),
                onTapOutside: (_) => _submitRename(),
              )
            : GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Text(
                  item.name,
                  style: item.isDone
                      ? const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('minus-${item.id}'),
              onPressed: item.quantity > 1
                  ? () => widget.onQuantityChanged(item.quantity - 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text('${item.quantity}'),
            IconButton(
              key: ValueKey('plus-${item.id}'),
              onPressed: () => widget.onQuantityChanged(item.quantity + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
