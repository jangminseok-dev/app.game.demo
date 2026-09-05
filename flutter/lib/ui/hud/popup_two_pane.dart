import 'package:flutter/material.dart';

import 'pixel_ui.dart';

/// 팝업 본문 한 단. 아래에 그 단만의 일괄 단추와 경고가 붙는다(스펙 4.5·4.7).
///
/// `GamePopup` 의 본문처럼 **높이가 확정된 곳에서만** 쓴다 — 안쪽 `Expanded` 가 무한 높이에서 터진다.
class PopupPane extends StatelessWidget {
  const PopupPane({super.key, required this.child, this.action, this.warning});

  final Widget child;

  /// 이 단에만 걸리는 일괄 단추. 없으면 자리를 안 만든다.
  final Widget? action;

  /// 되돌릴 수 없는 동작에 붙는 붉은 한 줄. 단추 바로 위에 선다.
  final String? warning;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: PixelText(warning!, size: 9, color: PixelPalette.hpLow),
          ),
        if (action != null)
          Padding(padding: const EdgeInsets.all(6), child: action!),
      ],
    );
  }
}

/// 팝업 본문 2단 — 왼쪽은 지금 붙어 있는 것, 오른쪽은 고를 수 있는 목록(스펙 4.4).
///
/// 여덟 화면이 같은 문법을 쓴다. 어느 창을 열어도 왼쪽이 "내 것",
/// 오른쪽이 "바꿀 것"이라 매번 새로 읽지 않아도 된다.
///
/// `GamePopup` 의 본문처럼 **높이가 확정된 곳에서만** 쓴다 — 안쪽 `Expanded` 가 무한 높이에서 터진다.
class PopupTwoPane extends StatelessWidget {
  const PopupTwoPane({super.key, required this.left, required this.right});

  final PopupPane left;
  final PopupPane right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: 6),
        Expanded(child: right),
      ],
    );
  }
}
