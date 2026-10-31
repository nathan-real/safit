import 'test_protocol.dart';

enum TestPhase {
  /// Le test est lancé, on attend les premiers traits noirs pour démarrer.
  armed,
  running,

  /// Le sujet a arrêté de pédaler, le volant ralentit.
  deceleration,
  finished,
  aborted,
}

/// Instantané d'un test en cours, mis à jour en continu par le service.
///
/// Pas de puissance ici : elle n'est connue qu'après la décélération,
/// qui donne la force de friction.
class TestSession {
  const TestSession({
    required this.protocol,
    required this.phase,
    this.elapsed = Duration.zero,
    this.cadenceRpm,
    this.heartRateBpm,
    this.targetCadenceRpm,
    this.stageIndex,
    this.stageCount,
    this.stageRemaining,
    this.remaining,
    this.decelerationCurve = const [],
    this.decelerationSlope,
    this.decelerationR2,
  });

  final TestProtocol protocol;
  final TestPhase phase;
  final Duration elapsed;
  final double? cadenceRpm;
  final int? heartRateBpm;

  /// Cadence visée pendant le palier en cours (test incrémental).
  final double? targetCadenceRpm;

  /// Palier en cours, à partir de 0.
  final int? stageIndex;
  final int? stageCount;

  /// Temps avant le palier suivant (test incrémental).
  final Duration? stageRemaining;

  /// Temps restant avant le signal d'arrêt, pour les tests de durée fixe.
  final Duration? remaining;

  /// Vitesse du volant pendant la décélération : (secondes depuis l'arrêt, rpm).
  final List<(double, double)> decelerationCurve;

  /// Pente de la décélération (rpm par seconde, négative), connue à la fin.
  /// Elle sert à calculer la force de friction de la courroie.
  final double? decelerationSlope;

  /// Alignement des points de la décélération (0..1) : proche de 1 = linéaire.
  final double? decelerationR2;

  bool get isActive =>
      phase == TestPhase.armed ||
      phase == TestPhase.running ||
      phase == TestPhase.deceleration;

  TestSession copyWith({
    TestPhase? phase,
    Duration? elapsed,
    double? cadenceRpm,
    int? heartRateBpm,
    double? targetCadenceRpm,
    int? stageIndex,
    int? stageCount,
    Duration? stageRemaining,
    Duration? remaining,
    List<(double, double)>? decelerationCurve,
    double? decelerationSlope,
    double? decelerationR2,
  }) {
    return TestSession(
      protocol: protocol,
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      cadenceRpm: cadenceRpm ?? this.cadenceRpm,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      targetCadenceRpm: targetCadenceRpm ?? this.targetCadenceRpm,
      stageIndex: stageIndex ?? this.stageIndex,
      stageCount: stageCount ?? this.stageCount,
      stageRemaining: stageRemaining ?? this.stageRemaining,
      remaining: remaining ?? this.remaining,
      decelerationCurve: decelerationCurve ?? this.decelerationCurve,
      decelerationSlope: decelerationSlope ?? this.decelerationSlope,
      decelerationR2: decelerationR2 ?? this.decelerationR2,
    );
  }
}
