import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/dungeon.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/quest.dart';
import 'package:idle_fantasy/domain/save_codec.dart';
import 'package:idle_fantasy/domain/skill.dart';

void main() {
  const config = BalanceConfig();
  const engine = BattleEngine(config);
  final rng = Random(9);

  /// 조각이 넉넉하고 칸이 다 열린 상태.
  GameState ready({int pages = 5000}) => GameState.initial(config).copyWith(
        highestStage: 300,
        dungeon: DungeonState(skillPages: pages),
      );

  group('해금과 장착', () {
    test('조각을 내고 스킬을 연다', () {
      final s = engine.unlockSkill(ready(), SkillId.slash)!;
      expect(s.skills.unlocked, contains(SkillId.slash));
      expect(s.dungeon.skillPages, 5000 - SkillId.slash.pageCost);
      expect(s.skills.at(0), SkillId.slash, reason: '빈 칸이 있으면 바로 끼워 준다');
    });

    test('조각이 모자라면 못 연다', () {
      expect(engine.unlockSkill(ready(pages: 0), SkillId.slash), isNull);
    });

    test('이미 연 스킬은 또 못 연다', () {
      final s = engine.unlockSkill(ready(), SkillId.slash)!;
      expect(engine.unlockSkill(s, SkillId.slash), isNull);
    });

    test('안 연 스킬은 장착되지 않는다', () {
      final s = engine.equipSkill(ready(), 0, SkillId.meteor);
      expect(s.skills.at(0), isNull);
    });

    test('같은 스킬을 다른 칸에 넣으면 두 칸이 맞바뀐다', () {
      var s = ready();
      s = engine.unlockSkill(s, SkillId.slash)!; // 0번
      s = engine.unlockSkill(s, SkillId.bolt)!; // 1번
      s = engine.equipSkill(s, 1, SkillId.slash);
      expect(s.skills.at(1), SkillId.slash);
      expect(s.skills.at(0), SkillId.bolt, reason: '자리를 맞바꾼다');
    });

    test('칸은 층에 따라 열린다', () {
      expect(skillSlotsOpen(1), 1);
      expect(skillSlotsOpen(119), 1);
      expect(skillSlotsOpen(120), 2);
      expect(skillSlotsOpen(200), 3);
    });

    test('아직 안 열린 칸에는 못 끼운다', () {
      var s = ready().copyWith(highestStage: 1);
      s = engine.unlockSkill(s, SkillId.slash)!;
      s = engine.unlockSkill(s, SkillId.bolt)!;
      s = engine.equipSkill(s, 1, SkillId.bolt);
      expect(s.skills.at(1), isNull, reason: '2번 칸은 120층부터');
    });

    test('해금 층은 해금표와 같다', () {
      final rows = unlockTable.where((e) => e.$2.startsWith('스킬 슬롯')).map((e) => e.$1).toList();
      expect(rows, skillSlotStages.skip(1).toList());
    });
  });

  group('발동', () {
    test('자동 스킬은 알아서 나가고 대기 시간이 찬다', () {
      var s = engine.unlockSkill(ready(), SkillId.slash)!;
      // 스킬 한 방(평타 ×4)이면 1층 몬스터는 바로 죽는다.
      s = engine.tick(s, 0.01, rng);
      expect(s.skills.cooldownAt(0), greaterThan(0), reason: '나갔으니 대기 중이다');
      expect(s.totalKills, greaterThan(0), reason: '스킬 피해가 실제로 들어갔다');
    });

    test('대기 중에는 다시 안 나간다', () {
      var s = engine.unlockSkill(ready(), SkillId.meteor)!;
      s = engine.tick(s, 0.1, rng);
      final cooldown = s.skills.cooldownAt(0);
      s = engine.tick(s, 0.1, rng);
      expect(s.skills.cooldownAt(0), lessThan(cooldown), reason: '줄기만 한다');
      expect(s.skills.cooldownAt(0), greaterThan(0));
    });

    test('시간이 지나면 다시 나간다', () {
      var s = engine.unlockSkill(ready(), SkillId.slash)!;
      s = engine.tick(s, 0.1, rng);
      for (var i = 0; i < SkillId.slash.cooldown * 10; i++) {
        s = engine.tick(s, 0.1, rng);
      }
      expect(s.skills.cooldownAt(0), greaterThan(0), reason: '한 바퀴 돌아 다시 나갔다');
    });

    test('자동을 끄면 알아서 안 나간다', () {
      var s = engine.unlockSkill(ready(), SkillId.slash)!;
      s = engine.toggleSkillAuto(s, 0);
      s = engine.tick(s, 0.1, rng);
      expect(s.skills.cooldownAt(0), 0, reason: '수동이라 그대로 있다');
    });

    test('수동이어도 탭하면 즉시 나간다', () {
      var s = engine.unlockSkill(ready(), SkillId.slash)!;
      s = engine.toggleSkillAuto(s, 0);
      final fired = engine.useSkill(s, 0, rng)!;
      expect(fired.skills.cooldownAt(0), SkillId.slash.cooldown);
      expect(engine.useSkill(fired, 0, rng), isNull, reason: '대기 중에는 못 쓴다');
    });

    test('빈 칸은 탭해도 아무 일도 없다', () {
      expect(engine.useSkill(ready(), 0, rng), isNull);
    });

    test('센 스킬이 더 아프다', () {
      for (var i = 1; i < SkillId.values.length; i++) {
        expect(SkillId.values[i].damageMultiplier,
            greaterThan(SkillId.values[i - 1].damageMultiplier));
        expect(SkillId.values[i].pageCost, greaterThan(SkillId.values[i - 1].pageCost));
      }
    });
  });

  test('스킬은 저장을 넘어 살아남는다', () {
    var s = engine.unlockSkill(ready(), SkillId.bolt)!;
    s = engine.toggleSkillAuto(s, 0);
    final back = decodeState(encodeState(s))!;
    expect(back.skills.unlocked, s.skills.unlocked);
    expect(back.skills.at(0), SkillId.bolt);
    expect(back.skills.isAuto(0), isFalse);
  });

  test('스킬 이전 저장도 읽힌다 — 기본은 자동', () {
    final j = encodeState(GameState.initial(config))..remove('skills');
    final back = decodeState(j)!;
    expect(back.skills.unlocked, isEmpty);
    expect(back.skills.isAuto(0), isTrue);
  });
}
