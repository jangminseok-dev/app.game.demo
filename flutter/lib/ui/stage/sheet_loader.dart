import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// 스프라이트 시트 JSON. PNG 가로 스트립과 쌍이다.
///
/// ```json
/// {"frame": [48, 48], "fps": 8, "animations": {"idle": [0, 3], "walk": [4, 9], ...}}
/// ```
class SheetSpec {
  const SheetSpec({required this.frame, required this.fps, required this.animations});

  final int frame;
  final int fps;

  /// 이름 → (시작 프레임, 끝 프레임). 끝 포함.
  final Map<String, (int, int)> animations;

  int get frameCount => animations.values.map((r) => r.$2).reduce((a, b) => a > b ? a : b) + 1;

  bool has(String name) => animations.containsKey(name);

  factory SheetSpec.fromJson(Map<String, dynamic> j) {
    final anims = <String, (int, int)>{};
    for (final e in (j['animations'] as Map<String, dynamic>).entries) {
      final r = e.value as List;
      final start = (r[0] as num).toInt(), end = (r[1] as num).toInt();
      if (start < 0 || start > end) throw FormatException('잘못된 범위: ${e.key} [$start, $end]');
      anims[e.key] = (start, end);
    }
    if (anims.isEmpty) throw const FormatException('애니메이션이 비어 있다');
    return SheetSpec(
      frame: ((j['frame'] as List)[0] as num).toInt(),
      fps: (j['fps'] as num).toInt(),
      animations: anims,
    );
  }
}

/// 이미지 + 스펙. 애니메이션은 호출마다 새로 만든다(컴포넌트마다 재생 위치가 다르다).
class LoadedSheet {
  LoadedSheet(this.image, this.spec);

  final ui.Image image;
  final SheetSpec spec;

  /// 없는 이름은 idle로 대체한다 — 물량 생성 중 walk가 아직 없는 시트가 있다.
  SpriteAnimation animation(String name, {required bool loop}) {
    final (start, end) = spec.animations[name] ?? spec.animations['idle']!;
    return SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.range(
        start: start,
        end: end,
        amount: spec.frameCount,
        stepTimes: List.filled(end - start + 1, 1 / spec.fps),
        textureSize: Vector2.all(spec.frame.toDouble()),
        loop: loop,
      ),
    );
  }
}

/// `assets/sprites/<group>/<id>.png` + `.json`을 읽고 캐시한다.
/// 에셋이 아직 없으면 단색 실루엣으로 대체해 앱이 죽지 않게 한다.
class SheetLoader {
  SheetLoader({Images? images, AssetBundle? bundle})
      : _images = images ?? Images(prefix: 'assets/sprites/'),
        _bundle = bundle ?? rootBundle;

  final Images _images;
  final AssetBundle _bundle;
  final _cache = <String, LoadedSheet>{};

  LoadedSheet? cached(String group, String id) => _cache['$group/$id'];

  Future<LoadedSheet> load(String group, String id, {required int size, required Color color}) async {
    final key = '$group/$id';
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final json = jsonDecode(await _bundle.loadString('assets/sprites/$key.json')) as Map<String, dynamic>;
      final spec = SheetSpec.fromJson(json);
      final image = await _images.load('$key.png');
      return _cache[key] = LoadedSheet(image, spec);
    } on Object catch (e) {
      debugPrint('시트 없음 $key — 대체 실루엣: $e');
      return _cache[key] = fallback(size: size, color: color);
    }
  }

  static LoadedSheet fallback({required int size, required Color color}) {
    final rec = ui.PictureRecorder();
    final s = size.toDouble();
    Canvas(rec)
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.16, s * 0.12, s * 0.68, s * 0.86), Radius.circular(s * 0.26)),
        Paint()..color = color,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.16, s * 0.12, s * 0.68, s * 0.86), Radius.circular(s * 0.26)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    return LoadedSheet(
      rec.endRecording().toImageSync(size, size),
      SheetSpec(frame: size, fps: 1, animations: const {'idle': (0, 0)}),
    );
  }
}
