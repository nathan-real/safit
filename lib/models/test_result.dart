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

  /// Palier, à partir de 0.
  final int index;
  final double targetCadenceRpm;
  final double? avgCadenceRpm;
  final int? avgHeartRateBpm;
  final double? avgPowerW;
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

  /// Vrai si la force et la puissance ont été calculées avec des paramètres
  /// d'ergocycle provisoires.
  final bool provisionalErgocycle;
}
