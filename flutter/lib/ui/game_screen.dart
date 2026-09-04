import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/game_controller.dart';
import '../domain/game_state.dart';
import '../domain/number_format.dart';
import '../domain/offline_reward.dart';
import '../domain/daily.dart';
import '../domain/dungeon.dart';
import '../domain/attendance.dart';
import '../domain/quest.dart';
import '../domain/upgrade.dart';
import 'attendance_panel.dart';
import 'battle_area.dart';
import 'daily_panel.dart';
import 'codex_screen.dart';
import 'dungeon_panel.dart';
import 'equipment_panel.dart';
import 'forge_panel.dart';
import 'hud/game_popup.dart';
import 'hud/pixel_icons.dart';
import 'hud/pixel_ui.dart';
import 'hud/reward_popup.dart';
import 'hud/skill_bar.dart';
import 'pet_panel.dart';
import 'quest_strip.dart';
import 'stage_select_panel.dart';

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
                  onTap: () => showGamePopup(context, title: '성장', child: const _UpgradeTab()),
                ),
                HudButton(
                  label: '장비',
                  icon: PixelIcon.shield,
                  onTap: () => showGamePopup(context, title: '장비', child: const EquipmentPanel()),
                ),
                HudButton(
                  label: '스킬',
                  icon: PixelIcon.spark,
                  onTap: () => showGamePopup(context, title: '스킬', child: const SkillSheet()),
                ),
                HudButton(
                  label: '펫',
                  icon: PixelIcon.egg,
                  onTap: () => showGamePopup(context, title: '펫', child: const PetPanel()),
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
        showRewardPopup(context, title: '${run.type.label} ${run.floor}층 클리어', lines: [
          '${run.type.currency.label} +${formatNumber(dungeonReward(run.type, run.floor, config))}',
        ]);
      }
    });

    final state = ref.watch(gameControllerProvider);
    final registered = state.codex.values.where((s) => s > 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFF12161A),
      body: Center(
        child: ConstrainedBox(
          // 세로 게임이라 데스크톱에서도 폰 폭으로 묶는다.
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              // ── 전투가 화면을 다 채운다. 위에 얹히는 것은 전부 겹침이다.
              const Positioned.fill(child: BattleArea()),

              // ── 보스 경고 띠
              Positioned(
                left: 0,
                right: 0,
                top: 150,
                child: BossWarningBanner(animation: _bossWarning),
              ),

              // ── 왼쪽: 지금 할 일
              const Positioned(left: 6, top: 84, child: QuestStrip()),

              // ── 오른쪽: 콘텐츠 · 도감
              Positioned(
                right: 6,
                top: 84,
                child: Column(
                  children: [
                    HudButton(
                      label: '던전',
                      icon: PixelIcon.gate,
                      badge: '${state.dungeon.tickets}',
                      alert: state.dungeon.tickets > 0 && state.dungeon.run == null,
                      onTap: () => showGamePopup(context, title: '던전', child: const DungeonPanel()),
                    ),
                    const SizedBox(height: 10),
                    HudButton(
                      label: '오늘',
                      icon: PixelIcon.calendar,
                      alert: anyDailyReady(state),
                      onTap: () => showGamePopup(context, title: '오늘 과제',
                          heightFactor: 0.5, child: const DailyPanel()),
                    ),
                    const SizedBox(height: 10),
                    HudButton(
                      label: '출석',
                      icon: PixelIcon.check,
                      alert: state.attendance.canClaim(epochDayOf(DateTime.now())),
                      onTap: () => showGamePopup(context, title: '출석부',
                          heightFactor: 0.55, child: const AttendancePanel()),
                    ),
                    const SizedBox(height: 10),
                    HudButton(
                      label: '이동',
                      icon: PixelIcon.pin,
                      alert: state.stageFailCount > 0 && state.stage == state.highestStage,
                      onTap: () => showGamePopup(context, title: '층 이동', child: const StageSelectPanel()),
                    ),
                    const SizedBox(height: 10),
                    HudButton(
                      label: '도감 $registered',
                      icon: PixelIcon.book,
                      onTap: () => showGamePopup(context, title: '도감', child: const CodexTab()),
                    ),
                  ],
                ),
              ),

              // ── 아래: 스킬 칸과 기능 단추
              Positioned(
                left: 0,
                right: 0,
                bottom: 66,
                child: SafeArea(top: false, child: const SkillBar()),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      HudButton(
                        label: '성장',
                        icon: PixelIcon.growth,
                        alert: _canBuyAnything(state),
                        onTap: () => showGamePopup(context, title: '성장', child: const _UpgradeTab()),
                      ),
                      HudButton(
                        label: '장비',
                        icon: PixelIcon.shield,
                        alert: state.equipment.canEnhance || state.equipment.inventory.isNotEmpty,
                        onTap: () => showGamePopup(context, title: '장비', child: const EquipmentPanel()),
                      ),
                      HudButton(
                        label: '대장간',
                        icon: PixelIcon.hammer,
                        alert: state.equipment.canCraft(ref.read(balanceConfigProvider)),
                        onTap: () => showGamePopup(context, title: '대장간', child: const ForgePanel()),
                      ),
                      HudButton(
                        label: '펫',
                        icon: PixelIcon.egg,
                        alert: state.hatchery.hasReady,
                        onTap: () => showGamePopup(context, title: '펫', child: const PetPanel()),
                      ),
                      HudButton(
                        label: '퀘스트',
                        icon: PixelIcon.flag,
                        alert: questReady(state),
                        onTap: () => showGamePopup(
                          context,
                          title: '퀘스트',
                          heightFactor: 0.4,
                          child: const Padding(padding: EdgeInsets.all(10), child: QuestStrip()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
