import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/game_state.dart';
import '../domain/number_format.dart';
import '../domain/offline_reward.dart';
import '../domain/daily.dart';
import '../domain/dungeon.dart';
import '../domain/attendance.dart';
import '../domain/upgrade.dart';
import 'attendance_panel.dart';
import 'battle_area.dart';
import 'daily_panel.dart';
import 'contents_panel.dart';
import 'forge_panel.dart';
import 'hud/game_popup.dart';
import 'hud/menu_grid.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'hud/portrait_tile.dart';
import 'hud/reward_popup.dart';
import 'hud/skill_bar.dart';
import 'hud/target_popup.dart';
import 'party_row.dart';
import 'quest_strip.dart';
import 'summon_panel.dart';

/// 메인 화면 — 전투가 화면을 다 채우고 기능은 그 위에 팝업으로 뜬다.
///
/// 탭으로 화면을 갈아 끼우면 전투가 사라져 "계속 크고 있다"는 감각이 끊긴다.
/// 레퍼런스처럼 전투를 배경으로 깔고 창을 띄운다.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with SingleTickerProviderStateMixin {
  /// 보스 경고 띠. 보스가 나타난 순간에만 한 번 돈다.
  late final AnimationController _bossWarning =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  /// 패배 팝업이 겹쳐 뜨는 것을 막는다.
  bool _defeatShown = false;

  @override
  void dispose() {
    _bossWarning.dispose();
    super.dispose();
  }

  /// 막혔을 때 어디를 키워야 하는지 알려 준다.
  ///
  /// 지는 것은 벌이 아니라 다음 할 일 안내다. 레퍼런스도 패배 즉시 성장 바로가기를 띄운다.
  Future<void> _showGrowthHint({required String title, required String message}) async {
    _defeatShown = true;
    await showGamePopup(
      context,
      title: title,
      icon: PixelIcon.growth,
      heightFactor: 0.34,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelText(message, size: 12, color: PixelPalette.textDim),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                HudButton(
                  label: '성장',
                  icon: PixelIcon.growth,
                  onTap: () => showGamePopup(context, title: '성장', icon: PixelIcon.growth,
                      help: '골드로 능력치 5종을 올린다. 살수록 비싸진다.', child: const _UpgradeTab()),
                ),
                HudButton(
                  label: '장비',
                  icon: PixelIcon.shield,
                  onTap: () => showTargetPopup(context, PopupTarget.hero),
                ),
                HudButton(
                  label: '스킬',
                  icon: PixelIcon.spark,
                  onTap: () => showGamePopup(context, title: '스킬', icon: PixelIcon.spark,
                      help: '스킬을 칸에 넣는다. AUTO면 알아서 나간다.', child: const SkillSheet()),
                ),
                HudButton(
                  label: '펫',
                  icon: PixelIcon.egg,
                  onTap: () => showTargetPopup(context, PopupTarget.pet),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (mounted) _defeatShown = false;
  }

  @override
  void initState() {
    super.initState();
    final reward = ref.read(offlineRewardProvider);
    if (reward != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOfflineReward(reward));
    }
  }

  void _showOfflineReward(OfflineReward reward) {
    final h = reward.elapsed.inHours;
    final m = reward.elapsed.inMinutes % 60;
    showGamePopup(
      context,
      title: '오프라인 보상',
      icon: PixelIcon.growth,
      heightFactor: 0.3,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelText('${h > 0 ? '$h시간 ' : ''}$m분 동안 자동 사냥', size: 12),
            const SizedBox(height: 8),
            PixelText('골드 +${formatNumber(reward.gold)}', size: 16, color: PixelPalette.gold),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 보스 등장과 패배는 순간이라 상태를 보고 있다가 그때만 연출한다.
    ref.listen(gameControllerProvider, (before, after) {
      if (before != null && !before.isBoss && after.isBoss) _bossWarning.forward(from: 0);
      if (before != null && !_defeatShown) {
        if (!before.isDown && after.isDown) {
          _showGrowthHint(title: '전투에 패배했습니다', message: '무엇을 키울지 골라 보세요');
        } else if (after.stageFailCount > before.stageFailCount) {
          _showGrowthHint(title: '시간이 모자랍니다', message: '이 층이 벽입니다. 무엇을 키울지 골라 보세요');
        }
      }

      // 던전을 깨고 나온 순간에만 보상 창을 띄운다.
      final run = before?.dungeon.run;
      if (run != null &&
          after.dungeon.run == null &&
          after.dungeon.clearedFloor(run.type) >= run.floor) {
        final config = ref.read(balanceConfigProvider);
        showRewardPopup(context, title: '${run.type.label} ${run.floor}층 클리어', icon: PixelIcon.gate, lines: [
          '${run.type.currency.label} +${formatNumber(dungeonReward(run.type, run.floor, config))}',
        ]);
      }
    });

    final state = ref.watch(gameControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF12161A),
      // 가로 화면. 노치가 좌우에 오므로 SafeArea로 감싼다.
      // 폭을 묶지 않는다 — 묶으면 GameWidget 뷰포트가 줄어 cover 배율이 화면이 아니라
      // 그 폭 기준으로 계산되고, 무대가 화면보다 좁게 그려져 옆에 띠가 남는다(백로그 D4-1).
      body: SafeArea(
        child: Stack(
          children: [
            // ── 전투가 화면을 다 채운다. 위에 얹히는 것은 전부 겹침이다.
            const Positioned.fill(child: BattleArea()),

            // ── 보스 경고 띠
            Positioned(left: 0, right: 0, top: 60, child: BossWarningBanner(animation: _bossWarning)),

            // ── 좌측 · 지금 할 일
            const Positioned(left: 6, top: 64, child: QuestStrip()),

            // ── 좌측 아래 · 시간이 차는 것
            Positioned(
              left: 6,
              bottom: 72,
              child: Row(
                children: [
                  HudButton(
                    label: '출석',
                    icon: PixelIcon.check,
                    alert: state.attendance.canClaim(epochDayOf(DateTime.now())),
                    onTap: () => showGamePopup(context, title: '출석부', icon: PixelIcon.check,
                        help: '하루 한 번 받는다. 빠져도 다음 칸부터 이어진다.', heightFactor: 0.55, child: const AttendancePanel()),
                  ),
                  const SizedBox(width: 8),
                  HudButton(
                    label: '오늘',
                    icon: PixelIcon.calendar,
                    alert: anyDailyReady(state),
                    onTap: () => showGamePopup(context, title: '오늘 과제', icon: PixelIcon.calendar,
                        help: '자정에 새로 시작한다. 셋을 따로 받는다.', heightFactor: 0.5, child: const DailyPanel()),
                  ),
                ],
              ),
            ),

            // ── 좌하단 · 바깥 소리 (광고 자리. SDK는 백로그 C3)
            Positioned(
              left: 6,
              bottom: 6,
              child: HudButton(
                label: '광고',
                icon: PixelIcon.spark,
                locked: true,
                onTap: () => _showComingSoon(context, '리워드 광고'),
              ),
            ),

            // ── 우상단 · 바깥으로 나가는 곳
            Positioned(
              right: 6,
              top: 6,
              child: Row(
                children: [
                  HudButton(
                    label: '콘텐츠',
                    icon: PixelIcon.gate,
                    badge: '${state.dungeon.tickets}',
                    alert: state.dungeon.tickets > 0 && state.dungeon.run == null,
                    onTap: () => showGamePopup(context, title: '콘텐츠', icon: PixelIcon.gate,
                        help: '던전은 표를 쓴다. 층 이동은 깬 층까지 갈 수 있다.', child: const ContentsPanel()),
                  ),
                  const SizedBox(width: 8),
                  HudButton(
                    label: '소환',
                    icon: PixelIcon.spark,
                    onTap: () => showGamePopup(context, title: '소환', icon: PixelIcon.spark,
                        help: '유물을 뽑아 주인공을 용으로 키운다. 중복은 승급에 쓰인다.',
                        child: const SummonPanel()),
                  ),
                  const SizedBox(width: 8),
                  HudButton(label: '상점', icon: PixelIcon.shop, locked: true, onTap: () => _showComingSoon(context, '상점')),
                  const SizedBox(width: 8),
                  HudButton(label: '메뉴', icon: PixelIcon.menu, onTap: () => showMenuGrid(context)),
                ],
              ),
            ),

            // ── 하단 중앙 · 내가 키우는 것. 레퍼런스 5칸과 같은 순서, 가운데만 크게.
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  HudButton(
                    label: '장비',
                    icon: PixelIcon.shield,
                    alert: state.equipment.canEnhance || state.equipment.inventory.isNotEmpty,
                    onTap: () => showTargetPopup(context, PopupTarget.hero),
                  ),
                  const SizedBox(width: 10),
                  HudButton(
                    label: '스킬',
                    icon: PixelIcon.spark,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: PixelPalette.panel,
                      builder: (_) => const SkillSheet(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  HudButton(
                    label: '대장간',
                    icon: PixelIcon.hammer,
                    big: true,
                    alert: state.equipment.canCraft(ref.read(balanceConfigProvider)),
                    onTap: () => showGamePopup(context, title: '대장간', icon: PixelIcon.hammer,
                        help: '강화석으로 장비를 만든다. 두드릴수록 좋은 것이 나온다.', child: const ForgePanel()),
                  ),
                  const SizedBox(width: 10),
                  HudButton(label: '무기', icon: PixelIcon.weapon, locked: true, onTap: () => _showComingSoon(context, '전용무기')),
                  const SizedBox(width: 10),
                  HudButton(
                    label: '성장',
                    icon: PixelIcon.growth,
                    alert: _canBuyAnything(state),
                    onTap: () => showGamePopup(context, title: '성장', icon: PixelIcon.growth,
                        help: '골드로 능력치 5종을 올린다. 살수록 비싸진다.', child: const _UpgradeTab()),
                  ),
                ],
              ),
            ),

            // ── 우하단 · 같이 싸우는 것. Task 4가 초상 줄을 채운다.
            Positioned(
              right: 6,
              bottom: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PartyPortraits(onSelect: (t) => showTargetPopup(context, t)),
                  const SizedBox(height: 6),
                  const SkillBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 아직 없는 기능을 눌렀을 때. 한 줄만 띄우고 끝낸다.
  void _showComingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: PixelText('$what — 준비 중', size: 12), duration: const Duration(seconds: 1)),
    );
  }

  /// 골드로 지금 살 수 있는 업그레이드가 하나라도 있는가. 성장 단추의 빨간 점 조건이다.
  bool _canBuyAnything(GameState state) {
    final config = ref.read(balanceConfigProvider);
    return UpgradeType.values.any((t) => state.gold >= t.cost(state.levelOf(t), config));
  }
}

class _UpgradeTab extends ConsumerWidget {
  const _UpgradeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final config = ref.watch(balanceConfigProvider);
    final saveStatus = ref.watch(saveStatusProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final stats = state.statsWith(config);
    final pending =
        state.killLog.values.fold(0, (a, b) => a + b) + state.bossKillLog.values.fold(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PixelPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PixelText('골드  ${formatNumber(state.gold)}', size: 18, color: PixelPalette.gold),
                  const Spacer(),
                  PixelText('DPS ${formatNumber(stats.dps(config))}', size: 12),
                ],
              ),
              const SizedBox(height: 6),
              PixelText(
                '공격 ${formatNumber(stats.attack)} · 속도 ${stats.attacksPerSecond.toStringAsFixed(1)}/s',
                size: 11,
                color: PixelPalette.textDim,
              ),
              const SizedBox(height: 2),
              PixelText(
                '치명 ${(stats.critChance * 100).toStringAsFixed(0)}% · 골드 ×${stats.goldMultiplier.toStringAsFixed(2)}',
                size: 11,
                color: PixelPalette.textDim,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final type in UpgradeType.values) ...[
          _UpgradeRow(
            type: type,
            level: state.levelOf(type),
            cost: type.cost(state.levelOf(type), config),
            affordable: state.gold >= type.cost(state.levelOf(type), config),
            onBuy: () => controller.buyUpgrade(type),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
        PixelText('총 처치 ${state.totalKills} · 미보고 처치 $pending', size: 11, color: PixelPalette.textDim),
        const SizedBox(height: 3),
        PixelText(_saveLine(context, saveStatus), size: 10, color: PixelPalette.textDim),
        if (saveStatus.lastRejectedRule != null) ...[
          const SizedBox(height: 3),
          PixelText(
            '서버 검증 거부(${saveStatus.lastRejectedRule}) — 서버 상태로 되돌렸습니다',
            size: 10,
            color: PixelPalette.hpLow,
          ),
        ],
      ],
    );
  }
}

String _saveLine(BuildContext context, SaveStatus s) {
  String hms(DateTime t) => '${TimeOfDay.fromDateTime(t).format(context)}:${t.second.toString().padLeft(2, '0')}';
  final saved = s.lastSavedAt == null ? '저장 전' : '로컬 저장 ${hms(s.lastSavedAt!)}';
  final synced = s.lastSyncedAt == null ? '서버 미동기화' : '서버 동기화 ${hms(s.lastSyncedAt!)}';
  return '$saved · $synced';
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.type,
    required this.level,
    required this.cost,
    required this.affordable,
    required this.onBuy,
  });

  final UpgradeType type;
  final int level;
  final double cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(child: PixelText(type.label, size: 12)),
          PixelText('Lv.$level', size: 11, color: PixelPalette.textDim),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: affordable ? onBuy : null,
            child: PixelPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: affordable ? PixelPalette.goldDark : const Color(0xFF3A3342),
              child: PixelText(
                '${formatNumber(cost)} G',
                size: 11,
                color: affordable ? PixelPalette.text : PixelPalette.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

