import 'test_protocol.dart';

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
    this.avgCadenceRpm,
    this.frictionForceN,
  });

  final String id;
  final TestProtocol protocol;
  final DateTime date;
  final Duration duration;
  final double? avgPowerW;

  /// Puissance maximale (test force-vitesse).
  final double? peakPowerW;
  final int? avgHeartRateBpm;
  final double? avgCadenceRpm;

  /// Force de friction déduite de la décélération.
  final double? frictionForceN;
}
