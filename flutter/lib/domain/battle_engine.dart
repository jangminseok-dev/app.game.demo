import 'dart:math';

import 'balance_config.dart';
import 'formulas.dart';
import 'game_state.dart';
import 'upgrade.dart';

/// 코어 루프의 전투 부분. GAME_DESIGN.md 2장·15장.
///
/// 순수 함수 모음이다. 시간(dt)과 난수를 밖에서 받으므로 테스트에서
/// 게임 시간을 원하는 만큼 빨리 돌릴 수 있다.
///
/// 스테이지 흐름:
///   일반 몬스터 [killsPerStage]마리 → 보스 등장(30초 제한)
///   보스 처치 → 다음 스테이지 / 시간 초과 → 같은 스테이지 일반 몬스터부터 다시
class BattleEngine {
  const BattleEngine(this.config);

  final BalanceConfig config;

  /// 한 틱 만큼 시간을 진행시킨 새 상태를 돌려준다.
  GameState tick(GameState s, double dt, Random rng) {
    if (s.isBoss) {
      final left = s.bossTimeLeft - dt;
      if (left <= 0) {
        return _spawnNormal(s.copyWith(killsOnStage: 0));
      }
      s = s.copyWith(bossTimeLeft: left);
    }

    final stats = s.stats;
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
    return _onKill(s, stats);
  }

  GameState _onKill(GameState s, Stats stats) {
    final reward = (s.isBoss
            ? bossGoldReward(s.stage, config)
            : goldReward(s.stage, config)) *
        stats.goldMultiplier;
    s = s.copyWith(gold: s.gold + reward, totalKills: s.totalKills + 1);

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
    );
  }

  GameState _spawnBoss(GameState s) {
    final hp = bossHp(s.stage, config);
    return s.copyWith(
      monsterHp: hp,
      monsterMaxHp: hp,
      isBoss: true,
      bossTimeLeft: config.bossTimeLimit,
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

  /// 공격속도가 극단적으로 높아졌을 때 한 틱에서 무한 루프를 막는 상한.
  static const _maxHitsPerTick = 1000;
}
