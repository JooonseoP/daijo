import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/domain/entities/shopping_item.dart';
import 'package:daijo/features/shopping_list/presentation/widgets/shopping_item_tile.dart';

ShoppingItem _item({int qty = 1, bool done = false}) => ShoppingItem(
      id: 1,
      name: '수세미',
      quantity: qty,
      isDone: done,
      createdAt: DateTime(2026),
    );

Widget _host(ShoppingItemTile tile) =>
    MaterialApp(home: Scaffold(body: ListView(children: [tile])));

void main() {
  testWidgets('checkbox tap reports toggled value', (tester) async {
    final toggled = <bool>[];
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(),
      onToggleDone: toggled.add,
      onRename: (_) {},
      onQuantityChanged: (_) {},
      onDelete: () {},
    )));

    await tester.tap(find.byKey(const ValueKey('check-1')));
    await tester.pump();
    expect(toggled, [true]);
  });

  testWidgets('plus increments, minus at 1 is disabled', (tester) async {
    final quantities = <int>[];
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(qty: 1),
      onToggleDone: (_) {},
      onRename: (_) {},
      onQuantityChanged: quantities.add,
      onDelete: () {},
    )));

    await tester.tap(find.byKey(const ValueKey('plus-1')));
    await tester.pump();
    expect(quantities, [2]);

    await tester.tap(find.byKey(const ValueKey('minus-1')));
    await tester.pump();
    expect(quantities, [2]); // still only the increment; minus disabled at 1
  });

  testWidgets('tapping name shows an editable field that reports rename',
      (tester) async {
    final renamed = <String>[];
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(),
      onToggleDone: (_) {},
      onRename: renamed.add,
      onQuantityChanged: (_) {},
      onDelete: () {},
    )));

    await tester.tap(find.text('수세미'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '철수세미');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(renamed, ['철수세미']);
  });

  testWidgets('swiping the tile reports delete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(),
      onToggleDone: (_) {},
      onRename: (_) {},
      onQuantityChanged: (_) {},
      onDelete: () => deleted = true,
    )));

    await tester.fling(
        find.byKey(const ValueKey('tile-1')), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('minus at qty 2 fires onQuantityChanged with 1', (tester) async {
    final quantities = <int>[];
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(qty: 2),
      onToggleDone: (_) {},
      onRename: (_) {},
      onQuantityChanged: quantities.add,
      onDelete: () {},
    )));

    await tester.tap(find.byKey(const ValueKey('minus-1')));
    await tester.pump();
    expect(quantities, [1]);
  });

  testWidgets('submitting same name does not fire onRename', (tester) async {
    final renamed = <String>[];
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: _item(),
      onToggleDone: (_) {},
      onRename: renamed.add,
      onQuantityChanged: (_) {},
      onDelete: () {},
    )));

    await tester.tap(find.text('수세미'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '수세미');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(renamed, isEmpty);
  });

  testWidgets(
      'edit controller reflects renamed item after parent rebuild (not mid-edit)',
      (tester) async {
    final original = ShoppingItem(
      id: 1,
      name: '수세미',
      quantity: 1,
      isDone: false,
      createdAt: DateTime(2026),
    );
    final renamed = ShoppingItem(
      id: 1,
      name: '철수세미',
      quantity: 1,
      isDone: false,
      createdAt: DateTime(2026),
    );

    // Pump with original item name.
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: original,
      onToggleDone: (_) {},
      onRename: (_) {},
      onQuantityChanged: (_) {},
      onDelete: () {},
    )));

    // Parent rebuilds with a new item whose name changed.
    await tester.pumpWidget(_host(ShoppingItemTile(
      item: renamed,
      onToggleDone: (_) {},
      onRename: (_) {},
      onQuantityChanged: (_) {},
      onDelete: () {},
    )));

    // Tap name to enter edit mode — TextField should be pre-filled with new name.
    await tester.tap(find.text('철수세미'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '철수세미'), findsOneWidget);
  });
}
