import 'dart:math';

import 'balance_config.dart';

/// GAME_DESIGN.md 4장의 공식. 스테이지는 1부터 시작한다.
double monsterHp(int stage, BalanceConfig c) =>
    c.monsterHpBase * pow(c.monsterHpGrowth, stage);

double bossHp(int stage, BalanceConfig c) =>
    monsterHp(stage, c) * c.bossHpMultiplier;

double goldReward(int stage, BalanceConfig c) =>
    c.goldBase * pow(c.goldGrowth, stage);

double bossGoldReward(int stage, BalanceConfig c) =>
    goldReward(stage, c) * c.bossGoldMultiplier;

/// 몬스터 한 대의 피해. 체력 성장(1.18)보다 느리게 올려 뒤로 갈수록
/// 맞아 죽는 것이 아니라 못 잡아서 막히게 한다.
double monsterAttack(int stage, BalanceConfig c) =>
    c.monsterAttackBase * pow(c.monsterAttackGrowth, stage);
