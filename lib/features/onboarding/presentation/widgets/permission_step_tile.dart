import 'package:flutter/material.dart';

import '../../../../core/permissions/permission_service.dart';

class PermissionStepTile extends StatelessWidget {
  const PermissionStepTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.locked = false,
    this.disclosure,
    this.onRequest,
    this.onOpenSettings,
  });

  final String title;
  final String description;
  final IconData icon;
  final PermissionStatus status;
  final bool locked;
  final String? disclosure;
  final VoidCallback? onRequest;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        if (locked)
                          const Text('🔒 잠김',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodySmall),
                    if (disclosure != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(disclosure!,
                            style: const TextStyle(
                                fontSize: 12, height: 1.5, color: Color(0xFF8A6D00))),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _trailing(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    if (locked) return const SizedBox.shrink();
    if (status == PermissionStatus.granted) {
      return const Row(children: [
        Icon(Icons.check_circle, color: Colors.green, size: 18),
        SizedBox(width: 6),
        Text('허용됨', style: TextStyle(color: Colors.green)),
      ]);
    }
    if (status == PermissionStatus.permanentlyDenied) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(onPressed: onOpenSettings, child: const Text('설정 열기')),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: onRequest,
        child: Text(disclosure != null ? '설정에서 허용' : '허용'),
      ),
    );
  }
}
