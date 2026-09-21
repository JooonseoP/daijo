import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shopping_list/presentation/home_page.dart';
import 'onboarding_providers.dart';
import 'widgets/permission_step_tile.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingControllerProvider.notifier).refresh();
    });
  }

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: theme.colorScheme.primary,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 30),
                  const SizedBox(height: 10),
                  Text('문 앞에서 알려드릴게요',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    '다이소 매장 근처에 도착하면 살 물건을 알림으로 보여드려요. 이를 위해 아래 권한이 필요해요.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  PermissionStepTile(
                    title: '위치 (앱 사용 중)',
                    description: '가까운 다이소 매장을 찾기 위해 현재 위치를 사용해요.',
                    icon: Icons.location_on,
                    status: state.whenInUse,
                    onRequest: controller.requestWhenInUse,
                    onOpenSettings: controller.openSettings,
                  ),
                  PermissionStepTile(
                    title: '위치 항상 허용',
                    description: '앱을 켜지 않아도 매장 근처 진입을 감지하려면 필요해요.',
                    icon: Icons.my_location,
                    status: state.always,
                    locked: !state.alwaysUnlocked,
                    disclosure:
                        '다이저는 매장 근처 알림을 위해 백그라운드에서 기기 위치를 확인합니다. '
                        '위치는 기기에만 사용되며 외부로 전송되지 않습니다.',
                    onRequest: controller.requestAlways,
                    onOpenSettings: controller.openSettings,
                  ),
                  PermissionStepTile(
                    title: '알림',
                    description: '매장 근처에서 쇼핑 목록을 알림으로 보여주기 위해 필요해요.',
                    icon: Icons.notifications,
                    status: state.notification,
                    onRequest: controller.requestNotification,
                    onOpenSettings: controller.openSettings,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('시작하기'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('권한 없이 목록만 사용할게요'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
