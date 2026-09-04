import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/balance_config.dart';
import '../domain/equipment.dart';
import '../domain/number_format.dart';
import 'hud/game_popup.dart';
import 'hud/pixel_ui.dart';

/// 장비 화면 — 왼쪽은 입고 있는 것, 오른쪽은 가방.
///
/// 레퍼런스의 인벤토리 문법을 그대로 따른다. 왼쪽 대상 · 오른쪽 목록 · 아래 일괄 단추.
/// 가방의 물건을 누르면 입고 있는 것과 나란히 비교하는 창이 뜬다.
class EquipmentPanel extends ConsumerWidget {
  const EquipmentPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final eq = state.equipment;
    final config = ref.watch(balanceConfigProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 왼쪽: 입고 있는 것과 강화
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    _EnhanceCard(equipment: eq, config: config, onEnhance: controller.enhance),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.1,
                      children: [
                        for (final slot in EquipSlot.values)
                          _SlotTile(slot: slot, item: eq.equipped[slot]),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // ── 오른쪽: 가방
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                      child: PixelText('가방 ${eq.inventory.length}', size: 11, color: PixelPalette.textDim),
                    ),
                    Expanded(
                      child: eq.inventory.isEmpty
                          ? const Center(
                              child: PixelText('비어 있음', size: 11, color: PixelPalette.textDim),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(2),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 5,
                                crossAxisSpacing: 5,
                                childAspectRatio: 0.95,
                              ),
                              itemCount: eq.inventory.length,
                              itemBuilder: (context, i) => GestureDetector(
                                onTap: () => _openCompare(context, ref, i),
                                child: _BagTile(item: eq.inventory[i]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── 아래: 일괄 단추
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Button(
                label: '자동 장착',
                enabled: eq.inventory.isNotEmpty,
                onTap: controller.autoEquip,
              ),
              _Button(
                label: '일괄 분해',
                enabled: eq.inventory.isNotEmpty,
                onTap: controller.scrapAll,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 입고 있는 것과 새 것을 나란히 놓고 고르게 한다.
  void _openCompare(BuildContext context, WidgetRef ref, int index) {
    final eq = ref.read(gameControllerProvider).equipment;
    if (index >= eq.inventory.length) return;
    final item = eq.inventory[index];
    final current = eq.equipped[item.slot];
    final controller = ref.read(gameControllerProvider.notifier);

    showGamePopup(
      context,
      title: item.slot.label,
      heightFactor: 0.42,
      child: Row(
        children: [
          Expanded(
            child: _CompareCard(
              caption: '입고 있음',
              item: current,
              action: null,
            ),
          ),
          Expanded(
            child: _CompareCard(
              caption: '가방',
              item: item,
              action: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Button(
                    label: '교체',
                    enabled: current == null || item.power > current.power,
                    onTap: () {
                      controller.equipAt(index);
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(width: 6),
                  _Button(
                    label: '분해',
                    enabled: true,
                    onTap: () {
                      controller.scrapAt(index);
                      Navigator.of(context).maybePop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 비교 창의 한 쪽.
class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.caption, required this.item, required this.action});

  final String caption;
  final Equipment? item;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final grade = item?.grade;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: PixelPanel(
        padding: const EdgeInsets.all(10),
        border: grade == null ? PixelPalette.ink : Color(grade.color),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelText(caption, size: 10, color: PixelPalette.textDim),
            const SizedBox(height: 8),
            if (item == null)
              const PixelText('없음', size: 12, color: PixelPalette.textDim)
            else ...[
              PixelText(grade!.label, size: 13, color: Color(grade.color)),
              const SizedBox(height: 4),
              PixelText('공격력 +${formatNumber(item!.power)}', size: 11),
              const SizedBox(height: 2),
              PixelText('티어 ${item!.tier}', size: 10, color: PixelPalette.textDim),
              const SizedBox(height: 2),
              PixelText('분해 시 강화석 ${item!.scrapValue}', size: 10, color: PixelPalette.textDim),
            ],
            if (action != null) ...[
              const SizedBox(height: 10),
              action!,
            ],
          ],
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelText('+${equipment.enhanceLevel}', size: 22, color: PixelPalette.gold),
              const Spacer(),
              _Button(label: '강화', enabled: equipment.canEnhance, onTap: onEnhance),
            ],
          ),
          const SizedBox(height: 5),
          PixelText('공격력 ×${equipment.powerWith(config).toStringAsFixed(2)}', size: 11),
          const SizedBox(height: 2),
          PixelText('강화석 ${equipment.stones} / ${equipment.enhanceCost}',
              size: 10, color: PixelPalette.textDim),
          const SizedBox(height: 2),
          const PixelText('실패도 파괴도 없습니다', size: 9, color: PixelPalette.textDim),
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
      padding: const EdgeInsets.all(5),
      color: item == null ? const Color(0xFF241E2B) : PixelPalette.panel,
      border: grade == null ? PixelPalette.ink : Color(grade.color),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PixelText(slot.label, size: 10, color: item == null ? PixelPalette.textDim : PixelPalette.text),
          const SizedBox(height: 3),
          if (item == null)
            const PixelText('비어 있음', size: 9, color: PixelPalette.textDim)
          else ...[
            PixelText(grade!.label, size: 10, color: Color(grade.color)),
            PixelText('+${formatNumber(item!.power)}', size: 9, color: PixelPalette.textDim),
          ],
        ],
      ),
    );
  }
}

/// 가방 한 칸.
class _BagTile extends StatelessWidget {
  const _BagTile({required this.item});

  final Equipment item;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(4),
      border: Color(item.grade.color),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PixelText(item.slot.label, size: 10, color: Color(item.grade.color)),
          const SizedBox(height: 2),
          PixelText(item.grade.label, size: 9, color: PixelPalette.textDim),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: enabled ? PixelPalette.goldDark : const Color(0xFF3A3342),
        child: PixelText(label, size: 11, color: enabled ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
  }
}
