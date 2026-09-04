import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/balance_config.dart';
import '../domain/hatchery.dart';
import '../domain/number_format.dart';
import '../domain/pet.dart';
import 'hud/pixel_ui.dart';

/// 펫 화면 — 부화 3칸, 탐험 3칸, 가진 펫.
///
/// 둘 다 시간이 지나야 끝난다. 접속할 이유를 만드는 자리라 남은 시간을 크게 보여 준다.
class PetPanel extends ConsumerWidget {
  const PetPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final pets = state.pets;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const PixelText('부화', size: 13),
            const Spacer(),
            PixelText('용의 알 조각 ${state.dungeon.eggShards}', size: 11, color: PixelPalette.gold),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < HatcheryState.slots; i++) ...[
          _EggTile(
            slot: state.hatchery.eggAt(i),
            shards: state.dungeon.eggShards,
            config: config,
            onStart: (kind) => controller.startHatch(i, kind),
            onSpeedUp: () => controller.speedUpHatch(i),
            onCollect: () => controller.collectEgg(i),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
        const PixelText('용 탐험', size: 13),
        const SizedBox(height: 6),
        for (var i = 0; i < HatcheryState.slots; i++) ...[
          _ExpeditionTile(
            slot: state.hatchery.expeditionAt(i),
            config: config,
            onSend: () => controller.sendExpedition(i),
            onCollect: () => controller.collectExpedition(i),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            const PixelText('데리고 다니는 펫', size: 13),
            const Spacer(),
            PixelText(
              pets.active?.label ?? '없음',
              size: 11,
              color: pets.active == null ? PixelPalette.textDim : PixelPalette.gold,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (pets.owned.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: PixelText('알을 부화시키면 펫이 생깁니다', size: 11, color: PixelPalette.textDim)),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < pets.owned.length; i++)
                GestureDetector(
                  onTap: () => controller.activatePet(i),
                  child: _PetChip(pet: pets.owned[i], active: i == pets.activeIndex),
                ),
            ],
          ),
      ],
    );
  }
}

/// 부화 한 칸. 비어 있으면 알 3종을 고르게 하고, 부화 중이면 남은 시간을 보여 준다.
class _EggTile extends StatelessWidget {
  const _EggTile({
    required this.slot,
    required this.shards,
    required this.config,
    required this.onStart,
    required this.onSpeedUp,
    required this.onCollect,
  });

  final EggSlot? slot;
  final int shards;
  final BalanceConfig config;
  final void Function(EggKind kind) onStart;
  final VoidCallback onSpeedUp;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final egg = slot;
    if (egg == null) {
      return PixelPanel(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const PixelText('빈 칸', size: 11, color: PixelPalette.textDim),
            const Spacer(),
            for (final kind in EggKind.values) ...[
              _Button(
                label: '${kind.label} ${kind.cost}',
                enabled: shards >= kind.cost,
                onTap: () => onStart(kind),
              ),
              const SizedBox(width: 5),
            ],
          ],
        ),
      );
    }

    final ready = egg.ready;
    return PixelPanel(
      padding: const EdgeInsets.all(10),
      border: ready ? PixelPalette.gold : PixelPalette.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelText(egg.kind.label, size: 12, color: ready ? PixelPalette.gold : PixelPalette.text),
              const SizedBox(width: 8),
              PixelText(
                ready ? '부화 완료' : _clock(egg.remaining),
                size: 11,
                color: PixelPalette.textDim,
              ),
              const Spacer(),
              if (!ready) ...[
                _Button(label: '광고 -30분', enabled: true, onTap: onSpeedUp),
                const SizedBox(width: 5),
              ],
              _Button(label: '꺼내기', enabled: ready, onTap: onCollect),
            ],
          ),
          const SizedBox(height: 6),
          PixelGauge(
            value: (1 - egg.remaining / egg.kind.seconds).clamp(0.0, 1.0),
            color: ready ? PixelPalette.gold : PixelPalette.gem,
            height: 7,
          ),
        ],
      ),
    );
  }
}

/// 탐험 한 칸. 보내 두면 4시간 뒤에 골드와 알 조각을 준다.
class _ExpeditionTile extends StatelessWidget {
  const _ExpeditionTile({
    required this.slot,
    required this.config,
    required this.onSend,
    required this.onCollect,
  });

  final ExpeditionSlot? slot;
  final BalanceConfig config;
  final VoidCallback onSend;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final trip = slot;
    if (trip == null) {
      return PixelPanel(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            PixelText('${_clock(config.expeditionSeconds)} 탐험', size: 11, color: PixelPalette.textDim),
            const Spacer(),
            _Button(label: '보내기', enabled: true, onTap: onSend),
          ],
        ),
      );
    }

    final ready = trip.ready;
    return PixelPanel(
      padding: const EdgeInsets.all(10),
      border: ready ? PixelPalette.gold : PixelPalette.ink,
      child: Row(
        children: [
          PixelText(
            ready
                ? '골드 ${formatNumber(expeditionGold(trip.stage, config))} · 조각 ${expeditionShards(config)}'
                : '탐험 중 ${_clock(trip.remaining)}',
            size: 11,
            color: ready ? PixelPalette.gold : PixelPalette.textDim,
          ),
          const Spacer(),
          _Button(label: '받기', enabled: ready, onTap: onCollect),
        ],
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  const _PetChip({required this.pet, required this.active});

  final Pet pet;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: active ? PixelPalette.goldDark : PixelPalette.panel,
      border: Color(pet.grade.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelText(pet.label, size: 11, color: Color(pet.grade.color)),
          const SizedBox(height: 2),
          PixelText(
            '${pet.bonus.label} +${(pet.value * 100).toStringAsFixed(1)}%',
            size: 10,
            color: PixelPalette.textDim,
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        color: enabled ? PixelPalette.goldDark : const Color(0xFF3A3342),
        child: PixelText(label, size: 10, color: enabled ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
  }
}

String _clock(double seconds) {
  final s = seconds.ceil().clamp(0, 1 << 30);
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return '$h시간 $m분';
  if (m > 0) return '$m분';
  return '$s초';
}
