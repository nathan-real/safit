import 'dart:math';

import '../../models/ergocycle_parameters.dart';
import '../../models/test_result.dart';
import '../../models/test_session.dart';
import '../physics/power_model.dart';

/// Transforme un test terminé en résultats : moyennes de l'effort, force de
/// friction (à partir de la décélération) et puissance.
TestResult summarizeTest(
  TestSession session,
  ErgocycleParameters ergo, {
  required String id,
  required DateTime date,
}) {
  final samples = session.samples;
  final slope = session.decelerationSlope;
  final force = slope == null ? null : frictionForce(slope, ergo);
  double? powerAt(double? cadence) =>
      (force == null || cadence == null) ? null : mechanicalPower(cadence, force, ergo);

  final cadences = [for (final s in samples) ?s.cadenceRpm];
  final heartRates = [for (final s in samples) ?s.heartRateBpm];
  final avgCadence = _mean(cadences);
  final peakCadence = cadences.isEmpty ? null : cadences.reduce(max);

  final stageTargets = <int, double>{};
  for (final s in samples) {
    final index = s.stageIndex;
    if (index != null) stageTargets.putIfAbsent(index, () => s.targetCadenceRpm ?? 0);
  }

  return TestResult(
    id: id,
    protocol: session.protocol,
    date: date,
    duration: samples.isEmpty ? Duration.zero : samples.last.elapsed - samples.first.elapsed,
    avgCadenceRpm: avgCadence,
    peakCadenceRpm: peakCadence,
    avgHeartRateBpm: _mean(heartRates.map((h) => h.toDouble()).toList())?.round(),
    maxHeartRateBpm: heartRates.isEmpty ? null : heartRates.reduce(max),
    frictionForceN: force,
    decelerationSlope: slope,
    decelerationR2: session.decelerationR2,
    avgPowerW: powerAt(avgCadence),
    peakPowerW: powerAt(peakCadence),
    provisionalErgocycle: ergo.provisional,
    stages: [
      for (final MapEntry(key: index, value: target) in stageTargets.entries)
        _stage(index, target, samples.where((s) => s.stageIndex == index), powerAt),
    ],
  );
}

StageResult _stage(
  int index,
  double target,
  Iterable<TestSample> samples,
  double? Function(double?) powerAt,
) {
  final cadence = _mean([for (final s in samples) ?s.cadenceRpm]);
  final heartRate = _mean([for (final s in samples) ?s.heartRateBpm?.toDouble()]);
  return StageResult(
    index: index,
    targetCadenceRpm: target,
    avgCadenceRpm: cadence,
    avgHeartRateBpm: heartRate?.round(),
    avgPowerW: powerAt(cadence),
  );
}

double? _mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
