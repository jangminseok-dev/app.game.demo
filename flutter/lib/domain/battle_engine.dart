import 'dart:math';

import 'balance_config.dart';
import 'codex.dart';
import 'dungeon.dart';
import 'formulas.dart';
import 'equipment.dart';
import 'game_state.dart';
import 'hatchery.dart';
import 'monster.dart';
import 'pet.dart';
import 'quest.dart';
import 'skill.dart';
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
  const BattleEngine(this.config, {this.catalog = MonsterCatalog.empty});

  final BalanceConfig config;
  final MonsterCatalog catalog;

  /// 장비 드롭 판정. 확률·티어 폭은 전부 마스터 데이터에서 온다.
  DropTable get dropTable => DropTable(config);

  /// 한 틱 만큼 시간을 진행시킨 새 상태를 돌려준다.
  GameState tick(GameState s, double dt, Random rng) {
    s = s.copyWith(
      dungeon: s.dungeon.regenerate(dt, config),
      hatchery: s.hatchery.advance(dt),
    );

    final run = s.dungeon.run;
    if (run != null) {
      final left = run.timeLeft - dt;
      // 시간 초과 — 실패다. 입장권은 돌려주지 않는다.
      if (left <= 0) return leaveDungeon(s, cleared: false);
      s = s.copyWith(dungeon: s.dungeon.copyWith(run: run.copyWith(timeLeft: left)));
    } else if (s.isBoss) {
      final left = s.bossTimeLeft - dt;
      if (left <= 0) {
        return _spawnNormal(s.copyWith(killsOnStage: 0));
      }
      s = s.copyWith(bossTimeLeft: left);
    }

    final stats = s.statsWith(config);
    // 자동 스킬이 먼저 나간다. 대기 시간이 돌아온 칸만 쏜다.
    s = s.copyWith(skills: s.skills.advance(dt));
    for (final slot in s.skills.autoReadySlots.toList()) {
      s = _castSkill(s, stats, slot, rng);
    }

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
    return _damage(s, stats, stats.attack * (isCrit ? config.critMultiplier : 1), rng);
  }

  GameState _damage(GameState s, Stats stats, double damage, Random rng) {
    final hp = s.monsterHp - damage;
    if (hp > 0) return s.copyWith(monsterHp: hp);
    return _onKill(s, stats, rng);
  }

  // ── 스킬. 자동으로 나가고 탭하면 즉시 나간다.

  /// 스킬서 조각을 내고 스킬을 연다. 조각이 모자라거나 이미 열었으면 null.
  GameState? unlockSkill(GameState s, SkillId id) {
    if (s.skills.unlocked.contains(id) || s.dungeon.skillPages < id.pageCost) return null;
    final skills = s.skills.unlock(id);
    // 빈 칸이 있으면 바로 끼워 준다 — 열고도 안 쓰는 일이 없게.
    final open = skillSlotsOpen(s.highestStage);
    final free = [for (var i = 0; i < open; i++) if (skills.at(i) == null) i];
    return s.copyWith(
      dungeon: s.dungeon.copyWith(skillPages: s.dungeon.skillPages - id.pageCost),
      skills: free.isEmpty ? skills : skills.equip(free.first, id),
    );
  }

  /// 열린 칸에 스킬을 끼운다. 아직 안 열린 칸이면 그대로 둔다.
  GameState equipSkill(GameState s, int slot, SkillId id) =>
      slot >= skillSlotsOpen(s.highestStage) ? s : s.copyWith(skills: s.skills.equip(slot, id));

  GameState toggleSkillAuto(GameState s, int slot) => s.copyWith(skills: s.skills.toggleAuto(slot));

  /// 탭으로 즉시 발동. 대기 중이면 null.
  GameState? useSkill(GameState s, int slot, Random rng) {
    if (!s.skills.isReady(slot)) return null;
    return _castSkill(s, s.statsWith(config), slot, rng);
  }

  GameState _castSkill(GameState s, Stats stats, int slot, Random rng) {
    final id = s.skills.at(slot);
    if (id == null) return s;
    return _damage(s.copyWith(skills: s.skills.fire(slot)), stats, stats.attack * id.damageMultiplier, rng);
  }

  GameState _onKill(GameState s, Stats stats, Random rng) {
    if (s.dungeon.run != null) return _onDungeonKill(s);

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

  // ── 던전. 필드와 같은 전투 루프를 쓰고 몬스터 체력과 보상만 다르다.

  /// 입장권을 쓰고 다음 층에 들어간다. 조건이 안 되면 null.
  GameState? enterDungeon(GameState s, DungeonType type) {
    if (!s.dungeon.canEnter(type, s.highestStage, config)) return null;
    final dungeon = s.dungeon.enter(type, s.highestStage, config);
    return _spawnDungeonWave(s.copyWith(dungeon: dungeon), dungeon.run!);
  }

  /// 던전을 끝내고 필드로 돌아온다. 클리어면 층이 오르고, 포기·시간 초과면 그대로다.
  GameState leaveDungeon(GameState s, {required bool cleared}) {
    final run = s.dungeon.run;
    if (run == null) return s;
    var next = s.copyWith(dungeon: s.dungeon.finish(cleared: cleared));
    if (cleared) next = _grantDungeonReward(next, run);
    // 필드로 복귀 — 보스 직전이었으면 보스부터 다시 만난다.
    return next.killsOnStage >= config.killsPerStage ? _spawnBoss(next) : _spawnNormal(next);
  }

  GameState _onDungeonKill(GameState s) {
    final run = s.dungeon.run!;
    s = s.copyWith(totalKills: s.totalKills + 1);
    final waves = run.wavesLeft - 1;
    if (waves <= 0) return leaveDungeon(s, cleared: true);
    final next = run.copyWith(wavesLeft: waves);
    return _spawnDungeonWave(s.copyWith(dungeon: s.dungeon.copyWith(run: next)), next);
  }

  GameState _spawnDungeonWave(GameState s, DungeonRun run) {
    final hp = dungeonMonsterHp(run.floor, config);
    return s.copyWith(
      monsterHp: hp,
      monsterMaxHp: hp,
      isBoss: false,
      bossTimeLeft: 0,
      monsterId: catalog.forStage(dungeonEquivalentStage(run.floor, config))?.id ?? s.monsterId,
    );
  }

  /// 층 보상을 재화별 자리에 넣는다. 골드와 강화석은 이미 있는 지갑으로 간다.
  GameState _grantDungeonReward(GameState s, DungeonRun run) {
    final amount = dungeonReward(run.type, run.floor, config);
    return switch (run.type.currency) {
      DungeonCurrency.gold => s.copyWith(gold: s.gold + amount),
      DungeonCurrency.stone =>
        s.copyWith(equipment: s.equipment.copyWith(stones: s.equipment.stones + amount.round())),
      final c => s.copyWith(dungeon: s.dungeon.addCurrency(c, amount.round())),
    };
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

  // ── 부화와 탐험. 진행은 [tick]이 하고 여기서는 넣고 꺼내는 것만 한다.

  /// 알 조각을 내고 빈 칸에 알을 올린다. 조각이 모자라거나 칸이 차 있으면 null.
  GameState? startHatch(GameState s, int index, EggKind kind) {
    if (s.hatchery.eggAt(index) != null || s.dungeon.eggShards < kind.cost) return null;
    return s.copyWith(
      dungeon: s.dungeon.copyWith(eggShards: s.dungeon.eggShards - kind.cost),
      hatchery: s.hatchery.putEgg(index, kind),
    );
  }

  /// 광고 보상 등으로 부화 시간을 줄인다.
  GameState speedUpHatch(GameState s, int index) =>
      s.copyWith(hatchery: s.hatchery.speedUp(index, config.adSpeedUpSeconds));

  /// 다 된 알을 꺼내 펫으로 만든다. 아직이면 null.
  GameState? collectEgg(GameState s, int index, Random rng) {
    final egg = s.hatchery.eggAt(index);
    if (egg == null || !egg.ready) return null;
    return s.copyWith(
      pets: s.pets.add(rollPet(rng, gradeBias: egg.kind.gradeBias)),
      hatchery: s.hatchery.takeEgg(index),
    );
  }

  /// 빈 칸에서 탐험을 보낸다. 이미 나가 있으면 null.
  GameState? sendExpedition(GameState s, int index) {
    if (s.hatchery.expeditionAt(index) != null) return null;
    return s.copyWith(hatchery: s.hatchery.sendExpedition(index, s.highestStage, config));
  }

  /// 돌아온 탐험의 보상을 받는다. 아직이면 null.
  GameState? collectExpedition(GameState s, int index) {
    final slot = s.hatchery.expeditionAt(index);
    if (slot == null || !slot.ready) return null;
    return s.copyWith(
      gold: s.gold + expeditionGold(slot.stage, config),
      dungeon: s.dungeon.copyWith(eggShards: s.dungeon.eggShards + expeditionShards(config)),
      hatchery: s.hatchery.takeExpedition(index),
    );
  }

  /// 조건을 채웠으면 지금 퀘스트 보상을 받고 다음 번호로 넘어간다. 아니면 null.
  GameState? claimQuest(GameState s) {
    final quest = s.quests.current;
    if (quest == null || questProgress(quest, s) < quest.target) return null;
    return grantQuestReward(s, quest, config).copyWith(quests: s.quests.claim());
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
