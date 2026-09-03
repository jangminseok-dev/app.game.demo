import 'dart:convert';
import 'dart:io';

import 'package:idle_fantasy/domain/monster.dart';

/// 번들 에셋(`assets/monsters.json`)을 파일로 읽는다. 위젯 바인딩 없이 순수 테스트에서 쓴다.
MonsterCatalog loadBundledCatalog() =>
    MonsterCatalog.fromJson(jsonDecode(File('assets/monsters.json').readAsStringSync()) as Map<String, dynamic>);

/// 작은 카탈로그 — 지역 2 × 몬스터 2. 서버 codex 테스트의 것과 같다.
const smallCatalog = MonsterCatalog(
  version: 1,
  regions: [
    Region(id: 'forest', name: '숲', stageFrom: 1, stageTo: 10, completionKind: PassiveKind.attack, completionValue: 20),
    Region(id: 'cave', name: '동굴', stageFrom: 11, stageTo: null, completionKind: PassiveKind.gold, completionValue: 20),
  ],
  monsters: [
    Monster(id: 1, name: '슬라임', region: 'forest', element: MonsterElement.neutral, rarity: 1.0, passiveKind: PassiveKind.gold, passivePerStar: 0.5),
    Monster(id: 2, name: '늑대', region: 'forest', element: MonsterElement.wind, rarity: 0.5, passiveKind: PassiveKind.attackSpeed, passivePerStar: 0.3),
    Monster(id: 3, name: '박쥐', region: 'cave', element: MonsterElement.wind, rarity: 1.0, passiveKind: PassiveKind.crit, passivePerStar: 0.2),
    Monster(id: 4, name: '골렘', region: 'cave', element: MonsterElement.earth, rarity: 0.3, passiveKind: PassiveKind.attack, passivePerStar: 0.6),
  ],
);
