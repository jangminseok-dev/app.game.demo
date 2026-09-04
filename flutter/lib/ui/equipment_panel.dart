import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/balance_config.dart';
import '../domain/equipment.dart';
import '../domain/number_format.dart';
import 'hud/pixel_ui.dart';

/// 장비 화면 — 착용 6부위, 강화, 인벤토리 일괄 분해.
///
/// 강화 레벨은 캐릭터에 붙으므로 부위별로 표시하지 않고 하나만 크게 보여 준다.
class EquipmentPanel extends ConsumerWidget {
  const EquipmentPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(gameControllerProvider).equipment;
    final config = ref.watch(balanceConfigProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _EnhanceCard(equipment: eq, config: config, onEnhance: controller.enhance),
        const SizedBox(height: 12),
        const _SectionLabel('착용'),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.05,
          children: [for (final slot in EquipSlot.values) _SlotTile(slot: slot, item: eq.equipped[slot])],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const _SectionLabel('가방'),
            const SizedBox(width: 8),
            PixelText('${eq.inventory.length}개', size: 11, color: PixelPalette.textDim),
            const Spacer(),
            _ActionButton(
              label: '일괄 분해',
              enabled: eq.inventory.isNotEmpty,
              onTap: controller.scrapAll,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (eq.inventory.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: PixelText('비어 있음 — 더 센 장비가 뜨면 자동으로 착용됩니다', size: 11, color: PixelPalette.textDim)),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final item in eq.inventory.take(40)) _ItemChip(item: item)],
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => PixelText(text, size: 13);
}

/// 강화 카드 — 강화 레벨, 강화석, 다음 비용.
class _EnhanceCard extends StatelessWidget {
  const _EnhanceCard({required this.equipment, required this.config, required this.onEnhance});

  final EquipmentState equipment;
  final BalanceConfig config;
  final VoidCallback onEnhance;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PixelText('강화', size: 12, color: PixelPalette.textDim),
              const SizedBox(height: 2),
              PixelText('+${equipment.enhanceLevel}', size: 26, color: PixelPalette.gold),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText('공격력 ×${equipment.powerWith(config).toStringAsFixed(2)}', size: 12),
                const SizedBox(height: 4),
                PixelText('강화석 ${equipment.stones} / ${equipment.enhanceCost}', size: 11, color: PixelPalette.textDim),
                const SizedBox(height: 4),
                const PixelText('실패도 파괴도 없습니다', size: 10, color: PixelPalette.textDim),
              ],
            ),
          ),
          _ActionButton(label: '강화', enabled: equipment.canEnhance, onTap: onEnhance),
        ],
      ),
    );
  }
}

/// 부위 한 칸. 비어 있으면 부위 이름만 흐리게 보여 다음 목표를 알린다.
class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.item});

  final EquipSlot slot;
  final Equipment? item;

  @override
  Widget build(BuildContext context) {
    final grade = item?.grade;
    return PixelPanel(
      padding: const EdgeInsets.all(6),
      color: item == null ? const Color(0xFF241E2B) : PixelPalette.panel,
      border: grade == null ? PixelPalette.ink : Color(grade.color),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PixelText(slot.label, size: 11, color: item == null ? PixelPalette.textDim : PixelPalette.text),
          const SizedBox(height: 4),
          if (item == null)
            const PixelText('비어 있음', size: 10, color: PixelPalette.textDim)
          else ...[
            PixelText(grade!.label, size: 11, color: Color(grade.color)),
            const SizedBox(height: 2),
            PixelText('+${formatNumber(item!.power)}', size: 10, color: PixelPalette.textDim),
          ],
        ],
      ),
    );
  }
}

/// 가방 속 장비 하나 — 등급색 테두리만으로 구분한다.
class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.item});

  final Equipment item;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      border: Color(item.grade.color),
      child: PixelText(item.label, size: 10, color: Color(item.grade.color)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        color: enabled ? PixelPalette.goldDark : const Color(0xFF3A3342),
        child: PixelText(label, size: 12, color: enabled ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
  }
}
