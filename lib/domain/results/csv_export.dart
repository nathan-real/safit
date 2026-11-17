import '../../models/test_protocol.dart';
import '../../models/test_recording.dart';
import '../../models/test_result.dart';
import '../../models/test_session.dart';

/// Fichier CSV d'un test, lisible dans Excel en français : colonnes séparées
/// par « ; », virgule décimale. Contient le bilan, puis les mesures seconde
/// par seconde (cadence, FC), puis les courbes de décélération.
String buildTestCsv(TestResult result, {TestRecording? recording, String? athlete}) {
  final lines = <String>[];
  void row(List<Object?> cells) => lines.add(cells.map(_cell).join(';'));

  row(['SAFiT', 'Export de test']);
  row(['Protocole', result.protocol.title]);
  row(['Date', _date(result.date)]);
  if (athlete != null) row(['Athlète', athlete]);
  row(['Durée de l\'effort (s)', result.duration.inMilliseconds / 1000]);
  row(['Puissance moyenne (W)', result.avgPowerW]);
  row(['Puissance max (W)', result.peakPowerW]);
  row(['FC moyenne (bpm)', result.avgHeartRateBpm]);
  row(['FC max (bpm)', result.maxHeartRateBpm]);
  row(['Cadence moyenne (tr/min)', result.avgCadenceRpm]);
  row(['Cadence max (tr/min)', result.peakCadenceRpm]);
  row(['Force de friction (N)', result.frictionForceN]);
  row(['Pente de décélération (tr/min/s)', result.decelerationSlope]);
  row(['R² décélération', result.decelerationR2]);
  if (result.protocol == TestProtocol.subMaximal) {
    row(['Pente FC / puissance (bpm/W)', result.heartRatePowerSlope]);
  }
  row(['Paramètres ergocycle provisoires', result.provisionalErgocycle ? 'oui' : 'non']);

  if (result.stages.isNotEmpty) {
    lines.add('');
    row(['Palier', 'Cadence cible (tr/min)', 'Cadence (tr/min)', 'FC (bpm)', 'Puissance (W)']);
    for (final s in result.stages) {
      row([s.index + 1, s.targetCadenceRpm, s.avgCadenceRpm, s.avgHeartRateBpm, s.avgPowerW]);
    }
  }
  if (result.bouts.isNotEmpty) {
    lines.add('');
    row(['Essai', 'Durée (s)', 'Puissance (W)', 'FC (bpm)', 'Cadence (tr/min)', 'Friction (N)', 'R² décélération']);
    for (final b in result.bouts) {
      row([
        b.index + 1,
        b.duration.inMilliseconds / 1000,
        b.avgPowerW,
        b.avgHeartRateBpm,
        b.avgCadenceRpm,
        b.frictionForceN,
        b.decelerationR2,
      ]);
    }
  }

  final bouts = recording?.bouts ?? const <RecordedBout>[];
  if (bouts.isNotEmpty) {
    lines.add('');
    lines.add('Mesures seconde par seconde');
    row(['Essai', 'Seconde', 'Cadence (tr/min)', 'FC (bpm)', 'Palier', 'Cadence cible (tr/min)']);
    for (var b = 0; b < bouts.length; b++) {
      for (final s in perSecond(bouts[b].samples)) {
        row([
          b + 1,
          s.second,
          s.cadenceRpm,
          s.heartRateBpm,
          s.stageIndex == null ? null : s.stageIndex! + 1,
          s.targetCadenceRpm,
        ]);
      }
    }

    lines.add('');
    lines.add('Décélération');
    row(['Essai', 'Temps depuis l\'arrêt (s)', 'Vitesse (tr/min)']);
    for (var b = 0; b < bouts.length; b++) {
      for (final (t, v) in bouts[b].decelerationCurve) {
        row([b + 1, t, v]);
      }
    }
  }
  return '${lines.join('\r\n')}\r\n';
}

/// Moyenne des mesures d'une seconde d'effort.
class SecondSample {
  const SecondSample({
    required this.second,
    this.cadenceRpm,
    this.heartRateBpm,
    this.stageIndex,
    this.targetCadenceRpm,
  });

  /// Seconde d'effort (0 = de 0 à 1 s).
  final int second;
  final double? cadenceRpm;
  final int? heartRateBpm;
  final int? stageIndex;
  final double? targetCadenceRpm;
}

/// Regroupe les mesures (≈4 par seconde) en une ligne par seconde.
List<SecondSample> perSecond(List<TestSample> samples) {
  final groups = <int, List<TestSample>>{};
  for (final s in samples) {
    groups.putIfAbsent(s.elapsed.inMilliseconds ~/ 1000, () => []).add(s);
  }
  return [
    for (final MapEntry(key: second, value: group) in groups.entries)
      SecondSample(
        second: second,
        cadenceRpm: _mean([for (final s in group) s.cadenceRpm]),
        heartRateBpm: _mean([for (final s in group) s.heartRateBpm?.toDouble()])?.round(),
        stageIndex: group.last.stageIndex,
        targetCadenceRpm: group.last.targetCadenceRpm,
      ),
  ]..sort((a, b) => a.second.compareTo(b.second));
}

/// Nom de fichier, ex. « safit_incremental_2026-11-17_14-32.csv ».
String csvFileName(TestResult result) {
  final d = result.date;
  return 'safit_${result.protocol.name}_${d.year}-${_two(d.month)}-${_two(d.day)}'
      '_${_two(d.hour)}-${_two(d.minute)}.csv';
}

double? _mean(List<double?> values) {
  final present = values.whereType<double>().toList();
  if (present.isEmpty) return null;
  return present.reduce((a, b) => a + b) / present.length;
}

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

String _cell(Object? value) {
  final text = switch (value) {
    null => '',
    int v => '$v',
    double v => _decimal(v),
    _ => '$value',
  };
  if (text.contains(';') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// Jusqu'à 3 décimales, sans zéros inutiles, avec une virgule.
String _decimal(double v) {
  var s = v.toStringAsFixed(3);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}
