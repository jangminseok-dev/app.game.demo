import 'dart:math';

import 'balance_config.dart';
import 'codex.dart';
import 'formulas.dart';
import 'equipment.dart';
import 'game_state.dart';
import 'monster.dart';
import 'upgrade.dart';

/// 코어 루프의 전투 부분. GAME_DESIGN.md 2장·15장.
///
/// 순수 함수 모음이다. 시간(dt)과 난수를 밖에서 받으므로 테스트에서
/// 게임 시간을 원하는 만큼 빨리 돌릴 수 있다.
///
/// 스테이지 흐름:
///   일반 몬스터 [killsPerStage]마리 → 보스 등장(30초 제한)
///   보스 처치 → 다음 스테이지 / 시간 초과 → 같은 스테이지 일반 몬스터부터 다시
///
/// 포획은 여기서 굴리지 않는다. 처치를 [GameState.killLog]에 세어 두면 서버가 판정한다(6장).
class BattleEngine {
  const BattleEngine(this.config, {this.catalog = MonsterCatalog.empty, this.dropTable = const DropTable()});

  final BalanceConfig config;
  final MonsterCatalog catalog;

  /// 장비 드롭 판정. 확률을 바꾸려면 이것만 갈아 끼운다.
  final DropTable dropTable;

  /// 한 틱 만큼 시간을 진행시킨 새 상태를 돌려준다.
  GameState tick(GameState s, double dt, Random rng) {
    if (s.isBoss) {
      final left = s.bossTimeLeft - dt;
      if (left <= 0) {
        return _spawnNormal(s.copyWith(killsOnStage: 0));
      }
      s = s.copyWith(bossTimeLeft: left);
    }

    final stats = s.statsWith(config);
    final interval = 1 / stats.attacksPerSecond;
    var timer = s.attackTimer + dt;
    var hits = 0;
    while (timer >= interval && hits < _maxHitsPerTick) {
      timer -= interval;
      hits++;
      s = _hit(s, stats, rng);
    }
    return s.copyWith(attackTimer: timer);
  }

  /// 공격 1회. 몬스터가 죽으면 보상과 다음 몬스터까지 처리한다.
  GameState _hit(GameState s, Stats stats, Random rng) {
    final isCrit = rng.nextDouble() < stats.critChance;
    final damage = stats.attack * (isCrit ? config.critMultiplier : 1);
    final hp = s.monsterHp - damage;
    if (hp > 0) {
      return s.copyWith(monsterHp: hp);
    }
    return _onKill(s, stats, rng);
  }

  GameState _onKill(GameState s, Stats stats, Random rng) {
    final reward = (s.isBoss
            ? bossGoldReward(s.stage, config)
            : goldReward(s.stage, config)) *
        stats.goldMultiplier;
    // 장비 드롭 — 보스는 반드시, 필드는 가끔. 더 센 것이면 자동 착용되고 밀린 것은 인벤토리로 간다.
    final drop = dropTable.roll(s.stage, isBoss: s.isBoss, rng: rng);
    s = s.copyWith(
      gold: s.gold + reward,
      totalKills: s.totalKills + 1,
      killLog: s.isBoss ? null : _increment(s.killLog, s.monsterId),
      bossKillLog: s.isBoss ? _increment(s.bossKillLog, s.monsterId) : null,
      equipment: drop == null ? null : s.equipment.pickUp(drop),
    );

    if (s.isBoss) {
      final next = s.stage + 1;
      return _spawnNormal(s.copyWith(
        stage: next,
        highestStage: max(s.highestStage, next),
        killsOnStage: 0,
      ));
    }

    final kills = s.killsOnStage + 1;
    if (kills >= config.killsPerStage) {
      return _spawnBoss(s.copyWith(killsOnStage: kills));
    }
    return _spawnNormal(s.copyWith(killsOnStage: kills));
  }

  GameState _spawnNormal(GameState s) {
    final hp = monsterHp(s.stage, config);
    return s.copyWith(
      monsterHp: hp,
      monsterMaxHp: hp,
      isBoss: false,
      bossTimeLeft: 0,
      monsterId: catalog.forStage(s.stage)?.id ?? s.monsterId,
    );
  }

  GameState _spawnBoss(GameState s) {
    final hp = bossHp(s.stage, config);
    return s.copyWith(
      monsterHp: hp,
      monsterMaxHp: hp,
      isBoss: true,
      bossTimeLeft: config.bossTimeLimit,
      monsterId: catalog.forStage(s.stage)?.id ?? s.monsterId,
    );
  }

  /// 골드가 충분하면 업그레이드 1레벨을 사고, 아니면 null.
  GameState? buyUpgrade(GameState s, UpgradeType type) {
    final level = s.levelOf(type);
    final cost = type.cost(level, config);
    if (s.gold < cost) return null;
    return s.copyWith(
      gold: s.gold - cost,
      levels: {...s.levels, type: level + 1},
    );
  }

  /// 도감을 바꾸고 패시브를 다시 계산한다. 도감은 항상 이 메서드로만 바꾼다.
  GameState withCodex(GameState s, Map<int, int> codex, {Map<int, int>? pity}) =>
      s.copyWith(codex: codex, pity: pity, passives: computePassives(codex, catalog));

  /// 서버 포획 이벤트를 도감에 반영한다.
  GameState applyCaptures(GameState s, List<CaptureEvent> captures) {
    if (captures.isEmpty) return s;
    final codex = {...s.codex};
    for (final c in captures) {
      codex[c.monsterId] = max(codex[c.monsterId] ?? 0, c.stars);
    }
    return withCodex(s, codex);
  }

  /// 서버가 수락한 처치 보고를 처치 기록에서 뺀다. 요청 중에 쌓인 처치는 남는다.
  GameState consumeKillLog(GameState s, Map<int, int> sentNormal, Map<int, int> sentBoss) =>
      s.copyWith(
        killLog: _subtract(s.killLog, sentNormal),
        bossKillLog: _subtract(s.bossKillLog, sentBoss),
      );

  static Map<int, int> _increment(Map<int, int> log, int id) => {...log, id: (log[id] ?? 0) + 1};

  static Map<int, int> _subtract(Map<int, int> log, Map<int, int> sent) {
    final out = <int, int>{};
    for (final e in log.entries) {
      final left = e.value - (sent[e.key] ?? 0);
      if (left > 0) out[e.key] = left;
    }
    return out;
  }

  /// 공격속도가 극단적으로 높아졌을 때 한 틱에서 무한 루프를 막는 상한.
  static const _maxHitsPerTick = 1000;
}
