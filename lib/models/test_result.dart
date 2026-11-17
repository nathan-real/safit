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

  /// Essai, à partir de 0.
  final int index;
  final Duration duration;
  final double? avgPowerW;
  final int? avgHeartRateBpm;
  final double? avgCadenceRpm;
  final double? frictionForceN;
  final double? decelerationR2;
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
}
