import 'package:flutter/material.dart';
import 'features/onboarding/presentation/splash_gate.dart';

class DaijoApp extends StatelessWidget {
  const DaijoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다이저',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00897B),
        useMaterial3: true,
      ),
      home: const SplashGate(),
    );
  }
}
