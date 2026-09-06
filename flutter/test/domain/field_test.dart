import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_fantasy/domain/balance_config.dart';
import 'package:idle_fantasy/domain/battle_engine.dart';
import 'package:idle_fantasy/domain/field.dart';
import 'package:idle_fantasy/domain/game_state.dart';
import 'package:idle_fantasy/domain/monster_unit.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

import '../support/catalog.dart';

void main() {
  const c = BalanceConfig();

  group('무대 좌표', () {
    test('걷는 띠가 하단 HUD 위에서 끝난다', () {
      // 하단 바가 논리 69다. 가장 낮은 배율(844×390에서 1.32)에서 세계 52를 가린다.
      // 띠의 아래 끝이 480-52=428보다 위에 있어야 몬스터가 안 가려진다.
      expect(fieldBottomY, lessThan(428));
      expect(fieldTopY, lessThan(fieldBottomY));
      expect(heroHomeY, inInclusiveRange(fieldTopY, fieldBottomY));
    });

    test('세로만 자른다 — 가로는 끝이 없다', () {
      expect(clampToBand(0), fieldTopY);
      expect(clampToBand(9999), fieldBottomY);
      expect(clampToBand(350), 350);
    });

    test('나타나는 자리는 카메라 오른쪽 끝 바깥이다', () {
      // 불감대 ±80 + 보이는 가로의 절반 320 = 주인공+400이 오른쪽 끝의 최댓값.
      expect(spawnAheadOfHero, greaterThan(400));
    });
  });

  group('끝없는 가로', () {
    test('몬스터는 주인공이 어디 있든 그 오른쪽에 나타난다', () {
      final engine = BattleEngine(c, catalog: loadBundledCatalog());
      // tick만으로는 빈 무리가 저절로 안 채워진다 — 무리를 다시 부르는 것은 킬 이벤트뿐이다.
      // 그래서 사거리 안에 한 방에 죽는 몬스터를 두고 평타가 바로 나가게 만들어
      // "잡으면 다음 무리가 주인공 기준으로 선다"를 실제로 겪게 한다.
      var s = GameState.initial(c).copyWith(
        heroX: 5000,
        heroY: heroHomeY,
        wave: [MonsterUnit(key: 0, id: 1, hp: 1, maxHp: 1, x: 5000, y: heroHomeY)],
        attackTimer: 1 / c.attackSpeedBase,
      );
      s = engine.tick(s, 0.016, Random(1));
      expect(s.wave, isNotEmpty, reason: '무리가 생겨야 한다');
      for (final m in s.wave) {
        expect(m.x, greaterThan(5000), reason: '주인공(5000) 오른쪽이어야 한다');
        expect(m.x, lessThan(5000 + spawnAheadOfHero + 100));
      }
    });

    test('무리가 비어도 왼쪽으로 되돌아가지 않는다 — 돌아갈 집이 없다', () {
      // 고치기 전에는 heroHomeX(58)로 100px/s로 되돌아가서 1초면 1134가 됐다.
      // 고친 뒤에는 새 무리가 오른쪽에 생기고 그쪽으로 가거나 제자리에 선다.
      final engine = BattleEngine(c, catalog: loadBundledCatalog());
      var s = GameState.initial(c).copyWith(heroX: 1234, heroY: heroHomeY, wave: const []);
      final before = s.heroX;
      s = engine.tick(s, 1.0, Random(1));
      expect(s.heroX, greaterThanOrEqualTo(before), reason: '왼쪽으로 갔다: ${s.heroX}');
    });

    test('쓰러져도 주인공의 가로 자리는 그대로다', () {
      // 초당 회복(6)이 이 거리·층에서 들어오는 피해(초당 4대)를 앞질러 30초 안에 안 죽는다.
      // "잡히면 가로 자리가 그대로다"를 확인하는 데는 회복이 필요 없으므로 이 테스트만 끈다.
      const noRegen = BalanceConfig(heroHpRegenRate: 0);
      final engine = BattleEngine(noRegen, catalog: loadBundledCatalog());
      var s = GameState.initial(noRegen).copyWith(heroX: 3000, heroHp: 1);
      // 쓰러지는 틱 안에서도 걷는 만큼은 자연스레 움직인다 — 그 직전 자리와 비교한다.
      var beforeHit = s.heroX;
      for (var i = 0; i < 600 && s.heroHp > 0; i++) {
        beforeHit = s.heroX;
        s = engine.tick(s, 0.05, Random(7));
      }
      expect(s.heroHp, 0, reason: '쓰러져야 이 테스트가 뜻이 있다');
      expect(s.heroX, closeTo(beforeHit, 10),
          reason: '되돌아가면 안 된다: $beforeHit -> ${s.heroX}');
    });
  });

  test('새 상태의 주인공은 0에서 시작한다', () {
    expect(GameState.initial(c).heroX, 0);
  });

  test('저장을 읽으면 주인공은 0이다 — 절대 위치는 저장할 뜻이 없다', () {
    // heroX는 지금 저장에 없다. 누가 넣으면 이 테스트가 잡는다.
    final json = encodeState(GameState.initial(c).copyWith(heroX: 777));
    expect(decodeState(json)!.heroX, 0);
  });
}
