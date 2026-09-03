import 'package:flutter/material.dart';

/// 동료 편성 3칸 — 8주차(편성 + 속성 상성)에서 채운다. 지금은 자리만 잡아 레이아웃을 고정한다.
class PartyRow extends StatelessWidget {
  const PartyRow({super.key});

  static const slots = 3;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('동료', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 12),
          for (var i = 0; i < slots; i++) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: outline, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add, size: 18, color: outline),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          Text('편성은 곧 열립니다', style: TextStyle(color: outline, fontSize: 12)),
        ],
      ),
    );
  }
}
