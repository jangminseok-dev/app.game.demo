/// 큰 수를 `1.23K / 4.56M / 7.89B` 형태로. GAME_DESIGN.md 4장.
String formatNumber(double value) {
  if (value < 1000) return value.floor().toString();
  const units = ['K', 'M', 'B', 'T', 'Qa', 'Qi'];
  var v = value;
  var i = -1;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  if (v >= 1000) return value.toStringAsExponential(2);
  return '${v.toStringAsFixed(2)}${units[i]}';
}
