import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/codex.dart';
import '../domain/monster.dart';

/// 도감 화면 — 지역별 등록 현황, 성급, 패시브. 미등록 몬스터는 이름을 가린다.
class CodexScreen extends ConsumerWidget {
  const CodexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(monsterCatalogProvider);
    final state = ref.watch(gameControllerProvider);
    final codex = state.codex;
    final completion = regionCompletion(codex, catalog);
    final p = state.passives;
    final registered = codex.values.where((s) => s > 0).length;

    return Scaffold(
      appBar: AppBar(title: Text('도감  $registered/${catalog.monsters.length}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            p.isEmpty
                ? '패시브 없음 — 몬스터를 잡으면 낮은 확률로 등록됩니다'
                : [
                    for (final k in PassiveKind.values)
                      if (p.of(k) != 0) '${k.label} ${k.format(p.of(k))}',
                  ].join('  ·  '),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          for (final region in catalog.regions) ...[
            const Divider(height: 24),
            _RegionHeader(region: region, done: completion[region.id]!),
            for (final m in catalog.monstersIn(region.id))
              _MonsterRow(monster: m, stars: codex[m.id] ?? 0),
          ],
        ],
      ),
    );
  }
}

class _RegionHeader extends StatelessWidget {
  const _RegionHeader({required this.region, required this.done});
  final Region region;
  final (int, int) done;

  @override
  Widget build(BuildContext context) {
    final complete = done.$1 == done.$2;
    final range = region.stageTo == null ? '${region.stageFrom}층~' : '${region.stageFrom}~${region.stageTo}층';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('${region.name}  $range  ${done.$1}/${done.$2}',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            '완성 ${region.completionKind.label} ${region.completionKind.format(region.completionValue)}',
            style: TextStyle(
              color: complete ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonsterRow extends StatelessWidget {
  const _MonsterRow({required this.monster, required this.stars});
  final Monster monster;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final known = stars > 0;
    final muted = Theme.of(context).colorScheme.outline;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: known ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(monster.element.label, style: const TextStyle(fontSize: 12)),
      ),
      title: Text(known ? monster.name : '???', style: known ? null : TextStyle(color: muted)),
      subtitle: Text(
        known
            ? '${monster.passiveKind.label} ${monster.passiveKind.format(monster.passivePerStar * stars)}  (★당 ${monster.passiveKind.format(monster.passivePerStar)})'
            : '${monster.passiveKind.label} ★당 ${monster.passiveKind.format(monster.passivePerStar)}',
        style: TextStyle(color: muted),
      ),
      trailing: Text('★' * stars + '☆' * (5 - stars), style: TextStyle(color: known ? Colors.amber : muted)),
    );
  }
}
