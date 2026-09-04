import 'dart:math';

import 'balance_config.dart';
import 'formulas.dart';

/// 알 3종. 오래 걸릴수록 좋은 펫이 나올 확률이 높다.
///
/// 시간이 곧 재화인 자리다. 짧은 알은 접속할 때마다, 긴 알은 자기 전에 걸어 두게 된다.
enum EggKind {
  small('작은 알', 30 * 60, 30, 1.0),
  medium('빛나는 알', 2 * 3600, 100, 1.25),
  large('용의 알', 6 * 3600, 250, 1.6);

  const EggKind(this.label, this.seconds, this.cost, this.gradeBias);

  final String label;

  /// 부화에 걸리는 시간(초).
  final double seconds;

  /// 알 조각 값.
  final int cost;

  /// 등급 추첨 보정. 클수록 좋은 등급이 잘 나온다.
  final double gradeBias;
}

/// 부화 중인 알 한 칸.
class EggSlot {
  const EggSlot({required this.kind, required this.remaining});

  final EggKind kind;

  /// 남은 시간(초). 0이면 꺼낼 수 있다.
  final double remaining;

  bool get ready => remaining <= 0;

  EggSlot advance(double seconds) =>
      EggSlot(kind: kind, remaining: max(0, remaining - seconds));

  Map<String, dynamic> toJson() => {'kind': kind.name, 'remaining': remaining};

  static EggSlot? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final kind = EggKind.values.where((k) => k.name == raw['kind']).firstOrNull;
    if (kind == null) return null;
    return EggSlot(kind: kind, remaining: (raw['remaining'] as num).toDouble());
  }
}

/// 탐험 중인 한 칸. 정해진 시간이 지나면 골드와 알 조각을 준다.
class ExpeditionSlot {
  const ExpeditionSlot({required this.remaining, required this.stage});

  final double remaining;

  /// 보낼 때의 최고 층. 보상은 이 층 기준으로 계산한다.
  final int stage;

  bool get ready => remaining <= 0;

  ExpeditionSlot advance(double seconds) =>
      ExpeditionSlot(remaining: max(0, remaining - seconds), stage: stage);

  Map<String, dynamic> toJson() => {'remaining': remaining, 'stage': stage};

  static ExpeditionSlot? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return ExpeditionSlot(
      remaining: (raw['remaining'] as num).toDouble(),
      stage: (raw['stage'] as num).toInt(),
    );
  }
}

/// 부화 3칸 + 탐험 3칸. 둘 다 시간이 지나야 끝난다.
class HatcheryState {
  const HatcheryState({
    this.eggs = const [null, null, null],
    this.expeditions = const [null, null, null],
  });

  static const empty = HatcheryState();
  static const slots = 3;

  final List<EggSlot?> eggs;
  final List<ExpeditionSlot?> expeditions;

  /// 꺼낼 수 있는 것이 하나라도 있는가. 화면의 레드닷 조건이다.
  bool get hasReady =>
      eggs.any((e) => e != null && e.ready) || expeditions.any((e) => e != null && e.ready);

  int get freeEggSlots => eggs.where((e) => e == null).length;

  /// 시간이 지난 만큼 모든 칸을 진행시킨다. 오프라인에도 같은 함수를 쓴다.
  HatcheryState advance(double seconds) {
    if (seconds <= 0) return this;
    return HatcheryState(
      eggs: [for (final e in eggs) e?.advance(seconds)],
      expeditions: [for (final e in expeditions) e?.advance(seconds)],
    );
  }

  HatcheryState putEgg(int index, EggKind kind) => _withEggs(index, EggSlot(kind: kind, remaining: kind.seconds));

  /// 광고 보상 등으로 남은 시간을 줄인다.
  HatcheryState speedUp(int index, double seconds) {
    final egg = _at(eggs, index);
    return egg == null ? this : _withEggs(index, egg.advance(seconds));
  }

  HatcheryState takeEgg(int index) => _withEggs(index, null);

  HatcheryState sendExpedition(int index, int stage, BalanceConfig c) =>
      _withExpeditions(index, ExpeditionSlot(remaining: c.expeditionSeconds, stage: stage));

  HatcheryState takeExpedition(int index) => _withExpeditions(index, null);

  EggSlot? eggAt(int index) => _at(eggs, index);

  ExpeditionSlot? expeditionAt(int index) => _at(expeditions, index);

  static T? _at<T>(List<T?> list, int index) =>
      index >= 0 && index < list.length ? list[index] : null;

  HatcheryState _withEggs(int index, EggSlot? slot) {
    if (index < 0 || index >= slots) return this;
    final next = [...eggs]..[index] = slot;
    return HatcheryState(eggs: next, expeditions: expeditions);
  }

  HatcheryState _withExpeditions(int index, ExpeditionSlot? slot) {
    if (index < 0 || index >= slots) return this;
    final next = [...expeditions]..[index] = slot;
    return HatcheryState(eggs: eggs, expeditions: next);
  }

  Map<String, dynamic> toJson() => {
        'eggs': [for (final e in eggs) e?.toJson()],
        'expeditions': [for (final e in expeditions) e?.toJson()],
      };

  factory HatcheryState.fromJson(Map<String, dynamic> j) => HatcheryState(
        eggs: _list(j['eggs'], EggSlot.fromJson),
        expeditions: _list(j['expeditions'], ExpeditionSlot.fromJson),
      );

  static List<T?> _list<T>(Object? raw, T? Function(Object?) parse) {
    final source = raw is List ? raw : const [];
    return [
      for (var i = 0; i < slots; i++) i < source.length ? parse(source[i]) : null,
    ];
  }
}

/// 탐험 한 번의 골드. 보낸 시점의 최고 층으로 계산한다.
double expeditionGold(int stage, BalanceConfig c) =>
    goldReward(stage, c) * c.expeditionGoldMultiplier;

/// 탐험 한 번의 알 조각.
int expeditionShards(BalanceConfig c) => c.expeditionShards;
