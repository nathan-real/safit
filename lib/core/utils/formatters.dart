const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// « 25 oct. · 14:32 »
String formatDateTime(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} · ${_two(d.hour)}:${_two(d.minute)}';

/// « 04:32 », ou « 1:04:32 » au-delà d'une heure.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = _two(d.inMinutes.remainder(60));
  final s = _two(d.inSeconds.remainder(60));
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
