import 'test_protocol.dart';

/// Résultats d'un palier du test incrémental.
class StageResult {
  const StageResult({
    required this.index,
    required this.targetCadenceRpm,
    this.avgCadenceRpm,
    this.avgHeartRateBpm,
    this.avgPowerW,
  });

  factory StageResult.fromJson(Map<String, Object?> j) => StageResult(
        index: j['index'] as int,
        targetCadenceRpm: (j['targetCadenceRpm'] as num).toDouble(),
        avgCadenceRpm: _double(j['avgCadenceRpm']),
        avgHeartRateBpm: j['avgHeartRateBpm'] as int?,
        avgPowerW: _double(j['avgPowerW']),
      );

  /// Palier, à partir de 0.
  final int index;
  final double targetCadenceRpm;
  final double? avgCadenceRpm;
  final int? avgHeartRateBpm;
  final double? avgPowerW;

  Map<String, Object?> toJson() => {
        'index': index,
        'targetCadenceRpm': targetCadenceRpm,
        'avgCadenceRpm': avgCadenceRpm,
        'avgHeartRateBpm': avgHeartRateBpm,
        'avgPowerW': avgPowerW,
      };
}

/// Résultats d'un essai du test sous-maximal.
class BoutResult {
  const BoutResult({
    required this.index,
    required this.duration,
    this.avgPowerW,
    this.avgHeartRateBpm,
    this.avgCadenceRpm,
    this.frictionForceN,
    this.decelerationR2,
  });

  factory BoutResult.fromJson(Map<String, Object?> j) => BoutResult(
        index: j['index'] as int,
        duration: Duration(milliseconds: j['durationMs'] as int),
        avgPowerW: _double(j['avgPowerW']),
        avgHeartRateBpm: j['avgHeartRateBpm'] as int?,
        avgCadenceRpm: _double(j['avgCadenceRpm']),
        frictionForceN: _double(j['frictionForceN']),
        decelerationR2: _double(j['decelerationR2']),
      );

  /// Essai, à partir de 0.
  final int index;
  final Duration duration;
  final double? avgPowerW;
  final int? avgHeartRateBpm;
  final double? avgCadenceRpm;
  final double? frictionForceN;
  final double? decelerationR2;

  Map<String, Object?> toJson() => {
        'index': index,
        'durationMs': duration.inMilliseconds,
        'avgPowerW': avgPowerW,
        'avgHeartRateBpm': avgHeartRateBpm,
        'avgCadenceRpm': avgCadenceRpm,
        'frictionForceN': frictionForceN,
        'decelerationR2': decelerationR2,
      };
}

/// Résultat enregistré d'un test terminé.
class TestResult {
  const TestResult({
    required this.id,
    required this.protocol,
    required this.date,
    required this.duration,
    this.avgPowerW,
    this.peakPowerW,
    this.avgHeartRateBpm,
    this.maxHeartRateBpm,
    this.avgCadenceRpm,
    this.peakCadenceRpm,
    this.frictionForceN,
    this.decelerationSlope,
    this.decelerationR2,
    this.stages = const [],
    this.bouts = const [],
    this.heartRatePowerSlope,
    this.provisionalErgocycle = false,
  });

  final String id;
  final TestProtocol protocol;
  final DateTime date;

  /// Durée de l'effort (sans la décélération).
  final Duration duration;
  final double? avgPowerW;

  /// Puissance maximale (test force-vitesse).
  final double? peakPowerW;
  final int? avgHeartRateBpm;
  final int? maxHeartRateBpm;
  final double? avgCadenceRpm;

  /// Cadence maximale atteinte (test force-vitesse).
  final double? peakCadenceRpm;

  /// Force de friction déduite de la décélération.
  final double? frictionForceN;

  /// Pente de la décélération (tr/min par seconde) et sa régularité (0..1).
  final double? decelerationSlope;
  final double? decelerationR2;

  /// Détail par palier (test incrémental).
  final List<StageResult> stages;

  /// Détail par essai (test sous-maximal).
  final List<BoutResult> bouts;

  /// Pente de la droite FC / puissance (bpm par watt) entre les deux essais
  /// du test sous-maximal : indicateur de l'aptitude aérobie (VO2max).
  /// Plus elle est faible, moins le cœur s'emballe quand l'effort augmente.
  final double? heartRatePowerSlope;

  /// Vrai si la force et la puissance ont été calculées avec des paramètres
  /// d'ergocycle provisoires.
  final bool provisionalErgocycle;

  factory TestResult.fromJson(Map<String, Object?> j) => TestResult(
        id: j['id'] as String,
        protocol: TestProtocol.values.byName(j['protocol'] as String),
        date: DateTime.parse(j['date'] as String),
        duration: Duration(milliseconds: j['durationMs'] as int),
        avgPowerW: _double(j['avgPowerW']),
        peakPowerW: _double(j['peakPowerW']),
        avgHeartRateBpm: j['avgHeartRateBpm'] as int?,
        maxHeartRateBpm: j['maxHeartRateBpm'] as int?,
        avgCadenceRpm: _double(j['avgCadenceRpm']),
        peakCadenceRpm: _double(j['peakCadenceRpm']),
        frictionForceN: _double(j['frictionForceN']),
        decelerationSlope: _double(j['decelerationSlope']),
        decelerationR2: _double(j['decelerationR2']),
        stages: [
          for (final s in (j['stages'] as List? ?? const []))
            StageResult.fromJson(s as Map<String, Object?>),
        ],
        bouts: [
          for (final b in (j['bouts'] as List? ?? const []))
            BoutResult.fromJson(b as Map<String, Object?>),
        ],
        heartRatePowerSlope: _double(j['heartRatePowerSlope']),
        provisionalErgocycle: j['provisionalErgocycle'] as bool? ?? false,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'protocol': protocol.name,
        'date': date.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'avgPowerW': avgPowerW,
        'peakPowerW': peakPowerW,
        'avgHeartRateBpm': avgHeartRateBpm,
        'maxHeartRateBpm': maxHeartRateBpm,
        'avgCadenceRpm': avgCadenceRpm,
        'peakCadenceRpm': peakCadenceRpm,
        'frictionForceN': frictionForceN,
        'decelerationSlope': decelerationSlope,
        'decelerationR2': decelerationR2,
        'stages': [for (final s in stages) s.toJson()],
        'bouts': [for (final b in bouts) b.toJson()],
        'heartRatePowerSlope': heartRatePowerSlope,
        'provisionalErgocycle': provisionalErgocycle,
      };
}

double? _double(Object? value) => (value as num?)?.toDouble();
