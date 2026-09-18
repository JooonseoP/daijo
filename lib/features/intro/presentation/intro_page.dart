import 'dart:async';
import 'package:flutter/material.dart';

import '../../shopping_list/presentation/home_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({
    super.key,
    this.duration = const Duration(seconds: 2),
    this.onFinished,
  });

  final Duration duration;
  final VoidCallback? onFinished;

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _finish);
  }

  void _finish() {
    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                '다이저',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '잊지 마세요, 문 앞에서 알려드릴게요',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '다이저는 다이소 매장 근처에 도착하면 살 물건을 알려주기 위해, '
                  '앱을 사용하지 않는 동안에도 기기 위치를 백그라운드에서 확인합니다. '
                  '위치 정보는 기기에만 사용되며 외부로 전송되지 않습니다.',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
