import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/codex.dart';
import '../domain/monster.dart';
import 'sprites/monster_sprite.dart';

/// 도감 화면 — 탭 밖에서 단독으로 열 때 쓴다.
class CodexScreen extends ConsumerWidget {
  const CodexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(monsterCatalogProvider);
    final registered = ref.watch(gameControllerProvider).codex.values.where((s) => s > 0).length;
    return Scaffold(
      appBar: AppBar(title: Text('도감  $registered/${catalog.monsters.length}')),
      body: const CodexTab(),
    );
  }
}

/// 도감 본문 — 지역별 스프라이트 그리드. 미등록은 실루엣, 탭하면 상세.
class CodexTab extends ConsumerWidget {
  const CodexTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(monsterCatalogProvider);
    final state = ref.watch(gameControllerProvider);
    final codex = state.codex;
    final completion = regionCompletion(codex, catalog);
    final p = state.passives;

    return ListView(
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
          for (final region in catalog.regions) ...[
            const SizedBox(height: 16),
            _RegionHeader(region: region, done: completion[region.id]!),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.78,
              children: [
                for (final m in catalog.monstersIn(region.id))
                  _MonsterCell(monster: m, stars: codex[m.id] ?? 0),
              ],
            ),
          ],
        ],
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
    return Row(
      children: [
        Container(
          width: 10,
          height: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: regionColors(region.id)),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${region.name}  $range  ${done.$1}/${done.$2}',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(
          '완성 ${region.completionKind.label} ${region.completionKind.format(region.completionValue)}',
          style: TextStyle(
            fontSize: 12,
            color: complete ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _MonsterCell extends ConsumerWidget {
  const _MonsterCell({required this.monster, required this.stars});
  final Monster monster;
  final int stars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final known = stars > 0;
    final muted = Theme.of(context).colorScheme.outline;
    return InkWell(
      onTap: () => _showDetail(context, ref),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: known ? Border.all(color: elementColor(monster.element).withValues(alpha: 0.6)) : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Expanded(child: Center(child: MonsterSprite(monster: monster, size: 44, silhouette: !known))),
            Text(
              known ? monster.name : '???',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: known ? null : muted),
            ),
            Text(
              known ? '★' * stars + '☆' * (5 - stars) : '☆☆☆☆☆',
              style: TextStyle(fontSize: 9, color: known ? Colors.amber : muted, letterSpacing: -1),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final known = stars > 0;
    final config = ref.read(balanceConfigProvider);
    final state = ref.read(gameControllerProvider);
    final progress = (state.pity[monster.id] ?? 0) + (state.killLog[monster.id] ?? 0) + (state.bossKillLog[monster.id] ?? 0);
    final threshold = config.pityThreshold(monster.rarity);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            MonsterSprite(monster: monster, size: 96, silhouette: !known),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(known ? monster.name : '???', style: Theme.of(context).textTheme.titleLarge),
                  Text('속성 ${monster.element.label}  ·  희귀도 ${monster.rarity <= 0.3 ? '희귀' : monster.rarity <= 0.6 ? '보통' : '흔함'}'),
                  const SizedBox(height: 8),
                  Text(
                    known
                        ? '${monster.passiveKind.label} ${monster.passiveKind.format(monster.passivePerStar * stars)}  (★당 ${monster.passiveKind.format(monster.passivePerStar)})'
                        : '등록하면 ${monster.passiveKind.label} ★당 ${monster.passiveKind.format(monster.passivePerStar)}',
                  ),
                  Text('★' * stars + '☆' * (5 - stars), style: const TextStyle(color: Colors.amber, fontSize: 18)),
                  if (stars < config.maxStars)
                    Text(
                      '확정 포획까지 ${(threshold - progress).clamp(0, threshold)}마리  ($progress / $threshold)',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
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
