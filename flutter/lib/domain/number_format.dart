/// 큰 수를 한글 단위로. `1만 2천` · `3억 4천만` · `5조`.
///
/// `1.23K`는 이 장르의 표기가 아니다. 레퍼런스도 전투력을 `1조374억`으로 적는다.
/// 만 단위로 끊어 읽는 쪽이 한국 플레이어에게 한눈에 들어온다.
String formatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  if (value < 0) return '-${formatNumber(-value)}';
  final n = value.floor();
  if (n < 10000) return '$n';

  // 만 · 억 · 조 · 경 순으로 네 자리씩 끊는다.
  const units = ['', '만', '억', '조', '경'];
  var rest = BigInt.from(n);
  final groups = <BigInt>[];
  final ten4 = BigInt.from(10000);
  while (rest > BigInt.zero && groups.length < units.length) {
    groups.add(rest % ten4);
    rest = rest ~/ ten4;
  }
  if (rest > BigInt.zero) return value.toStringAsExponential(2);

  // 가장 큰 두 자리만 읽는다. 그 아래는 눈에 안 들어온다.
  final top = groups.length - 1;
  final head = '${groups[top]}${units[top]}';
  if (top == 0) return head;

  final second = groups[top - 1];
  if (second == BigInt.zero) return head;
  // 한 칸 아래는 천 단위로 줄여 읽는다. 1234만 → 1234만, 12345678 → 1234만
  return '$head ${_short(second)}${units[top - 1]}';
}

/// 네 자리 묶음을 읽기 좋게 줄인다. 9000 → 9천, 1234 → 1234.
String _short(BigInt group) {
  final v = group.toInt();
  if (v == 0) return '';
  if (v % 1000 == 0) return '${v ~/ 1000}천';
  return '$v';
}
