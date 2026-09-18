import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/intro/presentation/intro_page.dart';

void main() {
  testWidgets('renders app name and background-location disclosure',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: IntroPage(onFinished: _noop)),
    ));

    expect(find.text('다이저'), findsOneWidget);
    expect(find.textContaining('백그라운드'), findsOneWidget);
  });

  testWidgets('calls onFinished after the duration elapses', (tester) async {
    var finished = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: IntroPage(
          duration: const Duration(milliseconds: 500),
          onFinished: () => finished = true,
        ),
      ),
    ));

    expect(finished, isFalse);
    await tester.pump(const Duration(milliseconds: 600));
    expect(finished, isTrue);
  });
}

void _noop() {}
