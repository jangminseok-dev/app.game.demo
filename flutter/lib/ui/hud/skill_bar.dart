import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../domain/skill.dart';
import 'pixel_ui.dart';

/// 스킬 바 — 스킬 3칸 + 펫 1칸. 자동 발동이 기본이고 탭하면 즉시 나간다.
///
/// 잠긴 칸도 숨기지 않고 자물쇠로 보여 다음 목표를 알린다(레퍼런스 방식).
/// 빈 칸이나 잠긴 칸을 누르면 스킬 목록이 올라온다.
class SkillBar extends ConsumerWidget {
  const SkillBar({super.key});

  static const slots = 4;
  static const height = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final open = skillSlotsOpen(state.highestStage);

    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < SkillState.slots; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _SkillSlot(
                skill: state.skills.at(i),
                locked: i >= open,
                cooldown: state.skills.cooldownAt(i),
                auto: state.skills.isAuto(i),
                lacksMp: state.heroMpOr(config) < (state.skills.at(i)?.mpCost ?? 0),
                onTap: () {
                  if (i >= open) return _openSheet(context);
                  if (state.skills.isReady(i)) return controller.useSkill(i);
                  if (state.skills.at(i) == null) _openSheet(context);
                },
                onLongPress: () => _openSheet(context),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _PetSlot(label: state.pets.active?.grade.label),
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PixelPalette.panel,
      builder: (_) => const SkillSheet(),
    );
  }
}

/// 스킬 목록 — 6종을 열고 칸에 끼우고 자동을 끈다.
class SkillSheet extends ConsumerWidget {
  const SkillSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final open = skillSlotsOpen(state.highestStage);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              const PixelText('스킬', size: 14),
              const SizedBox(width: 10),
              PixelText('스킬서 조각 ${state.dungeon.skillPages}', size: 11, color: PixelPalette.gold),
              const Spacer(),
              PixelText('칸 $open / ${SkillState.slots}', size: 11, color: PixelPalette.textDim),
            ],
          ),
          const SizedBox(height: 4),
          PixelText(
            '자동으로 나갑니다. 아껴 쓰려면 자동을 끄고 탭하세요.',
            size: 10,
            color: PixelPalette.textDim,
          ),
          const SizedBox(height: 10),
          for (final id in SkillId.values) ...[
            _SkillRow(
              id: id,
              unlocked: state.skills.unlocked.contains(id),
              equippedSlot: state.skills.equipped.indexOf(id),
              pages: state.dungeon.skillPages,
              openSlots: open,
              onUnlock: () => controller.unlockSkill(id),
              onEquip: (slot) => controller.equipSkill(slot, id),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 6),
          const PixelText('자동 발동', size: 12),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < open; i++) ...[
                GestureDetector(
                  onTap: () => controller.toggleSkillAuto(i),
                  child: PixelPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: state.skills.isAuto(i) ? PixelPalette.goldDark : const Color(0xFF3A3342),
                    child: PixelText(
                      '${i + 1}번 ${state.skills.isAuto(i) ? '자동' : '수동'}',
                      size: 11,
                      color: state.skills.isAuto(i) ? PixelPalette.text : PixelPalette.textDim,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.id,
    required this.unlocked,
    required this.equippedSlot,
    required this.pages,
    required this.openSlots,
    required this.onUnlock,
    required this.onEquip,
  });

  final SkillId id;
  final bool unlocked;
  final int equippedSlot;
  final int pages;
  final int openSlots;
  final VoidCallback onUnlock;
  final void Function(int slot) onEquip;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(10),
      border: equippedSlot >= 0 ? PixelPalette.gold : PixelPalette.ink,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(id.label, size: 12, color: unlocked ? PixelPalette.text : PixelPalette.textDim),
                const SizedBox(height: 3),
                PixelText(
                  '피해 ×${id.damageMultiplier.toStringAsFixed(1)} · ${id.targets}마리'
                  ' · 대기 ${id.cooldown.toStringAsFixed(0)}초 · 마력 ${id.mpCost.toStringAsFixed(0)}',
                  size: 10,
                  color: PixelPalette.textDim,
                ),
              ],
            ),
          ),
          if (!unlocked)
            _Button(
              label: '조각 ${id.pageCost}',
              enabled: pages >= id.pageCost,
              onTap: onUnlock,
            )
          else
            for (var slot = 0; slot < openSlots; slot++) ...[
              _Button(
                label: '${slot + 1}번',
                enabled: equippedSlot != slot,
                onTap: () => onEquip(slot),
              ),
              const SizedBox(width: 4),
            ],
        ],
      ),
    );
  }
}

class _SkillSlot extends StatelessWidget {
  const _SkillSlot({
    required this.skill,
    required this.locked,
    required this.cooldown,
    required this.auto,
    required this.lacksMp,
    required this.onTap,
    required this.onLongPress,
  });

  final SkillId? skill;
  final bool locked;
  final double cooldown;
  final bool auto;

  /// 대기 시간은 돌아왔는데 마력이 모자란 상태.
  final bool lacksMp;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ready = skill != null && cooldown <= 0 && !lacksMp;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: PixelPanel(
        padding: EdgeInsets.zero,
        color: locked ? const Color(0xFF241E2B) : PixelPalette.panelLight,
        border: ready ? PixelPalette.gold : PixelPalette.ink,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: locked
                ? const SizedBox(width: 16, height: 16, child: CustomPaint(painter: _LockIcon()))
                : skill == null
                    ? const PixelText('+', size: 16, color: PixelPalette.textDim)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PixelText(
                            skill!.label,
                            size: 10,
                            color: ready ? PixelPalette.gold : PixelPalette.textDim,
                          ),
                          if (cooldown > 0)
                            PixelText('${cooldown.ceil()}', size: 10, color: PixelPalette.textDim)
                          else if (lacksMp)
                            const PixelText('마력', size: 9, color: PixelPalette.gem)
                          else if (!auto)
                            const PixelText('탭', size: 9, color: PixelPalette.gem),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

/// 펫 칸 — 데리고 다니는 펫의 등급만 보여 준다.
class _PetSlot extends StatelessWidget {
  const _PetSlot({required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: EdgeInsets.zero,
      color: label == null ? const Color(0xFF241E2B) : PixelPalette.panelLight,
      border: PixelPalette.goldDark,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: label == null
              ? const SizedBox(width: 16, height: 16, child: CustomPaint(painter: _LockIcon()))
              : PixelText(label!, size: 10, color: PixelPalette.gold),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        color: enabled ? PixelPalette.goldDark : const Color(0xFF3A3342),
        child: PixelText(label, size: 10, color: enabled ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
  }
}

class _LockIcon extends CustomPainter {
  const _LockIcon();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFF6B5F78);
    final w = size.width, h = size.height;
    // 자물쇠 몸통 + 고리
    canvas.drawRect(Rect.fromLTWH(w * 0.18, h * 0.45, w * 0.64, h * 0.45), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.32, h * 0.18, w * 0.12, h * 0.3), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.56, h * 0.18, w * 0.12, h * 0.3), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.32, h * 0.18, w * 0.36, h * 0.12), p);
  }

  @override
  bool shouldRepaint(_LockIcon old) => false;
}
