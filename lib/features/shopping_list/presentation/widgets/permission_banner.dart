import 'package:flutter/material.dart';

class PermissionBanner extends StatelessWidget {
  const PermissionBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          border: Border.all(color: const Color(0xFFFFE082)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFF8A6D00)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '매장 근처 알림이 꺼져 있어요. 위치 "항상 허용"과 알림 권한이 필요해요.',
                style: TextStyle(color: Color(0xFF8A6D00), fontSize: 13),
              ),
            ),
            const Text('권한 켜기 ›',
                style: TextStyle(
                    color: Color(0xFF00695C), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
