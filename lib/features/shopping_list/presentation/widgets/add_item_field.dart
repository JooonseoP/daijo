import 'package:flutter/material.dart';

class AddItemField extends StatefulWidget {
  const AddItemField({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<AddItemField> createState() => _AddItemFieldState();
}

class _AddItemFieldState extends State<AddItemField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: '살 물건 입력…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _submit,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
