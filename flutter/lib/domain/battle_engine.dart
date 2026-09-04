import 'dart:math';

import 'balance_config.dart';
import 'codex.dart';
import 'dungeon.dart';
import 'formulas.dart';
import 'equipment.dart';
import 'field.dart';
import 'game_state.dart';
import 'hatchery.dart';
import 'monster.dart';
import 'monster_unit.dart';
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
      if (left <= 0) return leaveDungeon(s, cleared: false, rng: rng);
      s = s.copyWith(dungeon: s.dungeon.copyWith(run: run.copyWith(timeLeft: left)));
    } else if (s.isBoss) {
      final left = s.bossTimeLeft - dt;
      if (left <= 0) {
        return _spawnNormal(s.copyWith(killsOnStage: 0), rng);
      }
      s = s.copyWith(bossTimeLeft: left);
    }

    // 쓰러져 있으면 일어설 때까지 아무 일도 없다.
    if (s.isDown) return _reviveTick(s, dt);

    // 층 제한 시간 — 필드에서만, 보스전에는 보스 시간이 따로 돈다.
    if (s.dungeon.run == null && !s.isBoss) {
      final left = s.stageTimeLeftOr(config) - dt;
      if (left <= 0) return _failStage(s, rng);
      s = s.copyWith(stageTimeLeft: left);
    }
    s = _regenerate(s, dt);

    final stats = s.statsWith(config);

    // 주인공은 가장 가까운 몬스터에게, 몬스터들은 한꺼번에 주인공에게 다가간다.
    s = _move(s, dt);

    // 몬스터가 먼저 때린다. 여기서 쓰러지면 이번 틱은 끝이다.
    s = _monstersAttack(s, dt, rng);
    if (s.isDown) return s;

    // 자동 스킬 — 대기 시간이 돌아오고 마력이 있는 칸만 나간다.
    s = s.copyWith(skills: s.skills.advance(dt));
    for (final slot in s.skills.autoReadySlots.toList()) {
      s = _castSkill(s, stats, slot, rng);
    }

    // 평타는 사거리 안에 있을 때만 나간다.
    final interval = 1 / stats.attacksPerSecond;
    var timer = s.attackTimer + dt;
    if (!_heroInRange(s)) return s.copyWith(attackTimer: min(timer, interval));
    var hits = 0;
    while (timer >= interval && hits < _maxHitsPerTick) {
      timer -= interval;
      hits++;
      s = _hit(s, stats, rng);
    }
    return s.copyWith(attackTimer: timer);
  }

  // ── 이동과 교전.

  bool _heroInRange(GameState s) {
    final target = s.nearestMonster;
    return target != null &&
        distanceBetween(s.heroX, s.heroY, target.x, target.y) <= config.heroAttackRange;
  }

  /// 주인공은 가장 가까운 몬스터 앞까지, 몬스터는 저마다 주인공 앞까지 간다.
  ///
  /// 몬스터가 줄을 서서 한 마리씩 오는 것이 아니라 전부 동시에 달려든다.
  /// 겹치지 않게 서로 밀어내므로 주인공을 둘러싸는 모양이 된다.
  GameState _move(GameState s, double dt) {
    var hx = s.heroX;
    var hy = s.heroY;
    final target = s.nearestMonster;
    if (target == null) {
      // 아무도 없으면 제자리로 돌아간다.
      (hx, hy) = moveToward(hx, hy, heroHomeX, heroHomeY, config.heroMoveSpeed * dt);
    } else {
      final gap = distanceBetween(hx, hy, target.x, target.y) - config.heroAttackRange * 0.8;
      if (gap > 0) {
        (hx, hy) = moveToward(hx, hy, target.x, target.y, min(config.heroMoveSpeed * dt, gap));
      }
    }

    // 전부 한 점으로 몰리면 겹쳐 보인다. 주인공 둘레에 자리를 나눠 에워싼다.
    final ring = config.monsterAttackRange * 0.8;
    final moved = <MonsterUnit>[];
    for (var i = 0; i < s.wave.length; i++) {
      final m = s.wave[i];
      final angle = _ringAngle(i, s.wave.length);
      final tx = hx + cos(angle) * ring;
      final ty = hy + sin(angle) * ring;
      final gap = distanceBetween(m.x, m.y, tx, ty);
      if (gap < 0.5) {
        moved.add(m);
        continue;
      }
      final (mx, my) = moveToward(m.x, m.y, tx, ty, min(config.monsterMoveSpeed * dt, gap));
      final (cx, cy) = clampToField(mx, my);
      moved.add(m.copyWith(x: cx, y: cy));
    }
    return s.copyWith(heroX: hx, heroY: hy, wave: _separate(moved));
  }

  /// 무리가 설 각도. 몬스터는 오른쪽에서 오므로 오른쪽 반원에 부채꼴로 선다.
  double _ringAngle(int index, int count) {
    if (count <= 1) return 0;
    const spread = pi * 0.8;
    return -spread / 2 + spread * index / (count - 1);
  }

  /// 겹친 몬스터를 서로 밀어낸다. 한 무리가 최대 5마리라 전부 비교해도 싸다.
  List<MonsterUnit> _separate(List<MonsterUnit> units) {
    final out = [...units];
    for (var i = 0; i < out.length; i++) {
      for (var j = i + 1; j < out.length; j++) {
        final a = out[i];
        final b = out[j];
        var dx = b.x - a.x;
        var dy = b.y - a.y;
        var d = sqrt(dx * dx + dy * dy);
        if (d >= separationRadius) continue;
        if (d < 0.001) {
          dx = 0;
          dy = 1;
          d = 1;
        }
        final push = (separationRadius - d) / 2;
        final nx = dx / d * push;
        final ny = dy / d * push;
        final (ax, ay) = clampToField(a.x - nx, a.y - ny);
        final (bx, by) = clampToField(b.x + nx, b.y + ny);
        out[i] = a.copyWith(x: ax, y: ay);
        out[j] = b.copyWith(x: bx, y: by);
      }
    }
    return out;
  }

  /// 사거리 안에 붙은 몬스터가 주인공을 때린다.
  GameState _monstersAttack(GameState s, double dt, Random rng) {
    final interval = 1 / config.monsterAttacksPerSecond;
    final damage =
        monsterAttack(s.stage, config) * (s.isBoss ? config.bossAttackMultiplier : 1);
    var hp = s.heroHpOr(config);

    final next = <MonsterUnit>[];
    for (final m in s.wave) {
      var timer = m.attackTimer + dt;
      if (distanceBetween(m.x, m.y, s.heroX, s.heroY) > config.monsterAttackRange) {
        // 아직 못 닿았다. 붙자마자 몰아치지 않게 타이머를 한 번치로 묶어 둔다.
        next.add(m.copyWith(attackTimer: min(timer, interval)));
        continue;
      }
      var hits = 0;
      while (timer >= interval && hits < _maxHitsPerTick) {
        timer -= interval;
        hits++;
      }
      hp -= damage * hits;
      next.add(m.copyWith(attackTimer: timer));
    }

    s = s.copyWith(wave: next, heroHp: hp);
    return hp <= 0 ? _knockDown(s, rng) : s;
  }

  /// 주인공이 쓰러졌다. 무리는 흩어지고 같은 층 일반 몬스터부터 다시 시작한다.
  GameState _knockDown(GameState s, Random rng) {
    // 던전 중이었다면 그 판은 실패다.
    var next = s.dungeon.run == null ? s : s.copyWith(dungeon: s.dungeon.finish(cleared: false));
    next = next.copyWith(
      heroHp: 0,
      heroX: heroHomeX,
      heroY: heroHomeY,
      reviveLeft: config.heroReviveSeconds,
      killsOnStage: 0,
      stageTimeLeft: config.stageTimeLimit,
      attackTimer: 0,
      isBoss: false,
      bossTimeLeft: 0,
    );
    return _spawnNormal(next, rng);
  }

  GameState _reviveTick(GameState s, double dt) {
    final left = s.reviveLeft - dt;
    if (left > 0) return s.copyWith(reviveLeft: left);
    return s.copyWith(
      reviveLeft: 0,
      heroHp: s.maxHeroHp(config),
      heroMp: s.maxHeroMp(config),
    );
  }

  /// 체력과 마력이 시간에 따라 찬다.
  GameState _regenerate(GameState s, double dt) {
    final maxHp = s.maxHeroHp(config);
    final maxMp = s.maxHeroMp(config);
    return s.copyWith(
      heroHp: min(maxHp, s.heroHpOr(config) + maxHp * config.heroHpRegenRate * dt),
      heroMp: min(maxMp, s.heroMpOr(config) + config.heroMpRegenPerSecond * dt),
    );
  }

  /// 공격 1회. 맨 앞을 때린다.
  GameState _hit(GameState s, Stats stats, Random rng) {
    final isCrit = rng.nextDouble() < stats.critChance;
    return _strike(s, stats, stats.attack * (isCrit ? config.critMultiplier : 1), 1, rng);
  }

  /// 가까운 쪽부터 [targets]마리를 때린다. 죽은 것은 보상을 주고 무리에서 뺀다.
  ///
  /// 무리가 비면 다음 무리를 부른다. 광역 스킬이 무리를 한 번에 쓸어도 같은 길을 지난다.
  GameState _strike(GameState s, Stats stats, double damage, int targets, Random rng) {
    if (s.wave.isEmpty) return _refill(s, rng);

    // 주인공에게 가까운 순으로 맞는다. 줄 순서가 아니라 거리 순이다.
    final order = [for (var i = 0; i < s.wave.length; i++) i]
      ..sort((a, b) => distanceBetween(s.heroX, s.heroY, s.wave[a].x, s.wave[a].y)
          .compareTo(distanceBetween(s.heroX, s.heroY, s.wave[b].x, s.wave[b].y)));
    final hit = order.take(targets).toSet();

    final alive = <MonsterUnit>[];
    final dead = <MonsterUnit>[];
    for (var i = 0; i < s.wave.length; i++) {
      final unit = hit.contains(i) ? s.wave[i].damaged(damage) : s.wave[i];
      (unit.isDead ? dead : alive).add(unit);
    }
    s = s.copyWith(wave: alive);
    for (final unit in dead) {
      s = _onKill(s, unit, stats, rng);
    }
    return s.wave.isEmpty ? _refill(s, rng) : s;
  }

  /// 한 마리를 잡았을 때의 보상과 기록. 다음 몬스터를 부르지는 않는다.
  GameState _onKill(GameState s, MonsterUnit unit, Stats stats, Random rng) {
    // 던전에서는 골드도 도감 기록도 없다. 층 보상만 있다.
    if (s.dungeon.run != null) return s.copyWith(totalKills: s.totalKills + 1);

    final reward =
        (s.isBoss ? bossGoldReward(s.stage, config) : goldReward(s.stage, config)) * stats.goldMultiplier;
    // 장비 드롭 — 보스는 반드시, 필드는 가끔. 더 센 것이면 자동 착용되고 밀린 것은 인벤토리로 간다.
    final drop = dropTable.roll(s.stage, isBoss: s.isBoss, rng: rng);
    return s.copyWith(
      gold: s.gold + reward,
      totalKills: s.totalKills + 1,
      killsOnStage: s.isBoss ? null : s.killsOnStage + 1,
      killLog: s.isBoss ? null : _increment(s.killLog, unit.id),
      bossKillLog: s.isBoss ? _increment(s.bossKillLog, unit.id) : null,
      equipment: drop == null ? null : s.equipment.pickUp(drop),
    );
  }

  /// 다른 층으로 옮겨 간다. 최고 층 이하로만 갈 수 있고, 던전 중이거나 쓰러져 있으면 못 간다.
  ///
  /// 벽에 막히면 한 층만 반복하게 된다. 낮은 층에 내려가 사냥할 길이 있어야
  /// "막혔다"가 "할 일이 없다"로 이어지지 않는다(기획서 6장).
  GameState? travelTo(GameState s, int stage, Random rng) {
    if (s.dungeon.run != null || s.isDown) return null;
    final target = stage.clamp(1, s.highestStage);
    if (target == s.stage) return null;
    return _spawnNormal(
      s.copyWith(
        stage: target,
        killsOnStage: 0,
        isBoss: false,
        bossTimeLeft: 0,
        stageTimeLeft: config.stageTimeLimit,
        attackTimer: 0,
      ),
      rng,
    );
  }

  /// 시간을 넘겼다. 진행을 일부 잃고 같은 층을 처음 무리부터 다시 한다.
  ///
  /// 레퍼런스는 전부 잃지만 우리는 무한 층이라 전부 잃게 하면 어느 층에서 영영 막힌다.
  /// 잃는 비율은 마스터 데이터에 있고, 전생이 들어오면 1.0으로 올린다.
  GameState _failStage(GameState s, Random rng) {
    final kept = (s.killsOnStage * (1 - config.stageFailKillPenalty)).floor();
    return _spawnNormal(
      s.copyWith(
        killsOnStage: kept.clamp(0, config.killsPerStage),
        stageTimeLeft: config.stageTimeLimit,
        stageFailCount: s.stageFailCount + 1,
        attackTimer: 0,
      ),
      rng,
    );
  }

  /// 무리를 다 잡았다. 다음에 무엇이 오는지 정한다.
  GameState _refill(GameState s, Random rng) {
    if (s.dungeon.run != null) return _onDungeonWaveCleared(s, rng);
    if (s.isBoss) {
      final next = s.stage + 1;
      // 새 층이 시작되면 시간도 새로 준다.
      return _spawnNormal(
        s.copyWith(
          stage: next,
          highestStage: max(s.highestStage, next),
          killsOnStage: 0,
          stageTimeLeft: config.stageTimeLimit,
        ),
        rng,
      );
    }
    if (s.killsOnStage >= config.killsPerStage) return _spawnBoss(s);
    return _spawnNormal(s, rng);
  }

  // ── 던전. 필드와 같은 전투 루프를 쓰고 몬스터 체력과 보상만 다르다.

  /// 입장권을 쓰고 다음 층에 들어간다. 조건이 안 되면 null.
  GameState? enterDungeon(GameState s, DungeonType type, Random rng) {
    if (!s.dungeon.canEnter(type, s.highestStage, s.quests.claimed, config)) return null;
    final dungeon = s.dungeon.enter(type, s.highestStage, s.quests.claimed, config);
    return _spawnDungeonWave(s.copyWith(dungeon: dungeon), dungeon.run!, rng);
  }

  /// 던전을 끝내고 필드로 돌아온다. 클리어면 층이 오르고, 포기·시간 초과면 그대로다.
  GameState leaveDungeon(GameState s, {required bool cleared, required Random rng}) {
    final run = s.dungeon.run;
    if (run == null) return s;
    var next = s.copyWith(dungeon: s.dungeon.finish(cleared: cleared));
    if (cleared) next = _grantDungeonReward(next, run);
    // 필드로 복귀 — 보스 직전이었으면 보스부터 다시 만난다.
    return next.killsOnStage >= config.killsPerStage ? _spawnBoss(next) : _spawnNormal(next, rng);
  }

  GameState _onDungeonWaveCleared(GameState s, Random rng) {
    final run = s.dungeon.run!;
    final waves = run.wavesLeft - 1;
    if (waves <= 0) return leaveDungeon(s, cleared: true, rng: rng);
    final next = run.copyWith(wavesLeft: waves);
    return _spawnDungeonWave(s.copyWith(dungeon: s.dungeon.copyWith(run: next)), next, rng);
  }

  GameState _spawnDungeonWave(GameState s, DungeonRun run, Random rng) {
    final stage = dungeonEquivalentStage(run.floor, config);
    return _spawnWave(
      s,
      hp: dungeonMonsterHp(run.floor, config),
      id: catalog.forStage(stage)?.id ?? s.monsterId,
      count: _waveSize(rng),
      isBoss: false,
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

  // ── 무리 소환.

  int _waveSize(Random rng) =>
      config.waveSizeMin + rng.nextInt(max(1, config.waveSizeMax - config.waveSizeMin + 1));

  GameState _spawnNormal(GameState s, Random rng) => _spawnWave(
        s,
        hp: monsterHp(s.stage, config),
        id: catalog.forStage(s.stage)?.id ?? s.monsterId,
        count: _waveSize(rng),
        isBoss: false,
      );

  GameState _spawnBoss(GameState s) => _spawnWave(
        s,
        hp: bossHp(s.stage, config),
        id: catalog.forStage(s.stage)?.id ?? s.monsterId,
        count: 1,
        isBoss: true,
      );

  GameState _spawnWave(
    GameState s, {
    required double hp,
    required int id,
    required int count,
    required bool isBoss,
  }) {
    // 화면 밖 오른쪽에서 세로로 퍼져 들어온다. 한 줄로 서지 않게 x도 조금씩 어긋낸다.
    final span = fieldBottomY - fieldTopY;
    return s.copyWith(
      wave: [
        for (var i = 0; i < count; i++)
          MonsterUnit(
            key: s.waveSeq + i,
            id: id,
            hp: hp,
            maxHp: hp,
            x: monsterSpawnX + (i % 3) * 26,
            y: count == 1 ? heroHomeY : fieldTopY + span * i / (count - 1),
          ),
      ],
      waveSeq: s.waveSeq + count,
      isBoss: isBoss,
      bossTimeLeft: isBoss ? config.bossTimeLimit : 0,
    );
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

  /// 지금 이 칸을 쓸 수 있는가. 대기 시간과 마력을 함께 본다.
  bool canCast(GameState s, int slot) {
    final id = s.skills.at(slot);
    return id != null && s.skills.isReady(slot) && !s.isDown && s.heroMpOr(config) >= id.mpCost;
  }

  /// 탭으로 즉시 발동. 대기 중이거나 마력이 모자라면 null.
  GameState? useSkill(GameState s, int slot, Random rng) {
    if (!canCast(s, slot)) return null;
    return _castSkill(s, s.statsWith(config), slot, rng);
  }

  GameState _castSkill(GameState s, Stats stats, int slot, Random rng) {
    final id = s.skills.at(slot);
    if (id == null || s.heroMpOr(config) < id.mpCost) return s;
    s = s.copyWith(heroMp: s.heroMpOr(config) - id.mpCost);
    return _strike(
      s.copyWith(skills: s.skills.fire(slot)),
      stats,
      stats.attack * id.damageMultiplier,
      id.targets,
      rng,
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

  // ── 대장간. 강화석을 장비로 바꾼다.

  /// 강화석을 내고 장비 하나를 만든다. 강화석이 모자라면 null.
  ///
  /// 등급은 숙련도가 오를수록 유리해지고, 티어는 지금 층을 따른다.
  /// 만든 것이 더 세면 자동으로 입고 아니면 가방으로 간다.
  (GameState, Equipment)? craft(GameState s, Random rng) {
    final eq = s.equipment;
    if (!eq.canCraft(config)) return null;
    final luck = 1.0 + config.craftBiasPerLevel * eq.craftLevel;
    final item = Equipment(
      slot: EquipSlot.values[rng.nextInt(EquipSlot.values.length)],
      grade: rollGrade(rng, luck: luck),
      tier: dropTable.tierOf(s.stage),
    );
    final next = eq
        .copyWith(stones: eq.stones - eq.craftCost(config), craftLevel: eq.craftLevel + 1)
        .pickUp(item);
    return (s.copyWith(equipment: next), item);
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
