import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/shopping_item.dart';
import 'app_version_provider.dart';
import 'shopping_list_providers.dart';
import 'widgets/add_item_field.dart';
import 'widgets/shopping_item_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingItemsProvider);
    final controller = ref.watch(shoppingListControllerProvider);
    final version = ref.watch(appVersionProvider).maybeWhen(
          data: (v) => 'v$v',
          orElse: () => '',
        );

    return Scaffold(
      appBar: AppBar(title: const Text('다이저')),
      body: Column(
        children: [
          AddItemField(onSubmit: controller.add),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (items) => _buildList(items, controller),
            ),
          ),
          if (version.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                version,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<ShoppingItem> items, ShoppingListController c) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '살 물건을 추가하세요.\n매장 근처에 가면 알려드릴게요.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final pending = items.where((i) => !i.isDone).toList();
    final done = items.where((i) => i.isDone).toList();

    return ListView(
      children: [
        for (final item in pending) _tile(item, c),
        if (done.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('완료', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        for (final item in done) _tile(item, c),
      ],
    );
  }

  Widget _tile(ShoppingItem item, ShoppingListController c) {
    return ShoppingItemTile(
      item: item,
      onToggleDone: (v) => c.toggleDone(item.id, v),
      onRename: (name) => c.rename(item.id, name),
      onQuantityChanged: (q) => c.setQuantity(item.id, q),
      onDelete: () => c.delete(item.id),
    );
  }
}
