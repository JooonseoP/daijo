import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/presentation/widgets/add_item_field.dart';

void main() {
  testWidgets('submits trimmed text and clears the field', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AddItemField(onSubmit: submitted.add)),
    ));

    await tester.enterText(find.byType(TextField), '  수세미  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, ['수세미']);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('does not submit blank input', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AddItemField(onSubmit: submitted.add)),
    ));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, isEmpty);
  });
}
