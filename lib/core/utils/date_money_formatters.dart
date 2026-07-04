String formatDate(DateTime? value) {
  if (value == null) return '-';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String formatMoney(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index += 1) {
    final remaining = rounded.length - index;
    buffer.write(rounded[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(' ');
  }
  final sign = value < 0 ? '-' : '';
  return '$sign${buffer.toString()} EUR';
}

String isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

int daysUntil(DateTime date) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(start).inDays;
}
