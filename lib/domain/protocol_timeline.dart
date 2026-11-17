import '../models/test_protocol.dart';

/// Déroulement d'un protocole dans le temps : palier en cours, cadence cible,
/// temps restant, et moment où il faut arrêter de pédaler.
/// Partagé par le test simulé et le vrai test, pour qu'ils suivent les mêmes règles.
class ProtocolProgress {
  const ProtocolProgress({
    this.stageIndex,
    this.stageCount,
    this.targetCadenceRpm,
    this.stageRemaining,
    this.remaining,
    this.shouldStop = false,
  });

  final int? stageIndex;
  final int? stageCount;
  final double? targetCadenceRpm;
  final Duration? stageRemaining;
  final Duration? remaining;

  /// Vrai quand l'effort est fini : signal d'arrêter de pédaler.
  final bool shouldStop;
}

/// Paliers du test incrémental (tr/min), d'environ 1 minute chacun.
const incrementalStagesRpm = [40.0, 50.0, 60.0, 70.0, 80.0];
const incrementalStageDuration = Duration(minutes: 1);

/// Durée de l'effort pour les protocoles de durée fixe.
Duration? effortDuration(TestProtocol protocol) => switch (protocol) {
      TestProtocol.subMaximal => const Duration(minutes: 5),
      TestProtocol.frictionCalibration => const Duration(seconds: 5),
      TestProtocol.forceVelocity => const Duration(seconds: 7),
      TestProtocol.incremental => incrementalStageDuration * incrementalStagesRpm.length,
    };

ProtocolProgress protocolProgress(TestProtocol protocol, Duration elapsed) {
  final length = effortDuration(protocol)!;
  final shouldStop = elapsed >= length;

  if (protocol == TestProtocol.incremental) {
    final stage = (elapsed.inMilliseconds ~/ incrementalStageDuration.inMilliseconds)
        .clamp(0, incrementalStagesRpm.length - 1);
    return ProtocolProgress(
      stageIndex: stage,
      stageCount: incrementalStagesRpm.length,
      targetCadenceRpm: incrementalStagesRpm[stage],
      stageRemaining: _atLeastZero(incrementalStageDuration * (stage + 1) - elapsed),
      shouldStop: shouldStop,
    );
  }
  return ProtocolProgress(
    remaining: protocol == TestProtocol.forceVelocity ? null : _atLeastZero(length - elapsed),
    shouldStop: shouldStop,
  );
}

Duration _atLeastZero(Duration d) => d.isNegative ? Duration.zero : d;
