import 'test_session.dart';

/// Mesures brutes d'un test (un enregistrement par essai), gardées avec le
/// résultat pour l'export CSV et l'analyse a posteriori.
class TestRecording {
  const TestRecording(this.bouts);

  /// Construit l'enregistrement à partir des essais terminés.
  factory TestRecording.fromSessions(List<TestSession> sessions) => TestRecording([
        for (final s in sessions)
          RecordedBout(
            samples: s.samples,
            decelerationCurve: s.decelerationCurve,
            decelerationSlope: s.decelerationSlope,
            decelerationR2: s.decelerationR2,
          ),
      ]);

  factory TestRecording.fromJson(List<Object?> json) => TestRecording([
        for (final b in json) RecordedBout.fromJson(b! as Map<String, Object?>),
      ]);

  final List<RecordedBout> bouts;

  List<Object?> toJson() => [for (final b in bouts) b.toJson()];
}

class RecordedBout {
  const RecordedBout({
    required this.samples,
    required this.decelerationCurve,
    this.decelerationSlope,
    this.decelerationR2,
  });

  factory RecordedBout.fromJson(Map<String, Object?> j) => RecordedBout(
        samples: [
          for (final s in j['samples']! as List)
            TestSample(
              elapsed: Duration(milliseconds: (s as Map)['ms'] as int),
              cadenceRpm: (s['cadence'] as num?)?.toDouble(),
              heartRateBpm: s['hr'] as int?,
              stageIndex: s['stage'] as int?,
              targetCadenceRpm: (s['target'] as num?)?.toDouble(),
            ),
        ],
        decelerationCurve: [
          for (final p in j['deceleration']! as List)
            (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        decelerationSlope: (j['decelerationSlope'] as num?)?.toDouble(),
        decelerationR2: (j['decelerationR2'] as num?)?.toDouble(),
      );

  /// Mesures pendant l'effort (environ 4 par seconde).
  final List<TestSample> samples;

  /// Vitesse pendant la décélération : (secondes depuis l'arrêt, tr/min).
  final List<(double, double)> decelerationCurve;
  final double? decelerationSlope;
  final double? decelerationR2;

  Map<String, Object?> toJson() => {
        'samples': [
          for (final s in samples)
            {
              'ms': s.elapsed.inMilliseconds,
              'cadence': s.cadenceRpm,
              'hr': s.heartRateBpm,
              'stage': s.stageIndex,
              'target': s.targetCadenceRpm,
            },
        ],
        'deceleration': [for (final (t, v) in decelerationCurve) [t, v]],
        'decelerationSlope': decelerationSlope,
        'decelerationR2': decelerationR2,
      };
}
