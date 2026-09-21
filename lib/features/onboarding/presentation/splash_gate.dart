import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../intro/presentation/intro_page.dart';
import '../../shopping_list/presentation/home_page.dart';
import 'onboarding_page.dart';
import 'onboarding_providers.dart';

class SplashGate extends ConsumerWidget {
  const SplashGate({super.key, this.introDuration = const Duration(seconds: 2)});

  final Duration introDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntroPage(
      duration: introDuration,
      onFinished: () async {
        final completed =
            await ref.read(onboardingPreferencesProvider).isCompleted();
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                completed ? const HomePage() : const OnboardingPage(),
          ),
        );
      },
    );
  }
}
