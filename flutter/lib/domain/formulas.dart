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
