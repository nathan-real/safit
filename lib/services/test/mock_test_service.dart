import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/protocol_timeline.dart';
import '../../domain/signal_processing/linear_fit.dart';
import '../../models/test_protocol.dart';
import '../../models/test_session.dart';
import 'test_data_service.dart';

/// Test simulé, avec des valeurs plausibles pour chaque protocole.
class MockTestService implements TestDataService {
  static const _tick = Duration(milliseconds: 250);

  /// Délai simulé avant le passage des premiers traits.
  static const _armDelay = Duration(seconds: 2);

  /// Pente de ralentissement simulée pendant la décélération (rpm/s).
  /// Plus forte à chaque essai : la courroie a été resserrée.
  static const _decelerationRpmPerSecond = 12.0;
  static const _decelerationIncreasePerBout = 6.0;

  /// Le cœur bat plus vite quand l'effort est plus dur (essai suivant).
  static const _heartRateIncreasePerBout = 18;

  int _bout = 0;
  double get _deceleration => _decelerationRpmPerSecond + _decelerationIncreasePerBout * _bout;

  final _session = ValueNotifier<TestSession?>(null);
  final _random = Random();
  Timer? _timer;

  // Début de la décélération en cours (instant et vitesse à l'arrêt du pédalage).
  Duration? _decelerationStart;
  double? _decelerationStartRpm;

  @override
  ValueListenable<TestSession?> get session => _session;

  @override
  bool get isSimulation => true;

  @override
  Future<void> arm(TestProtocol protocol, {int bout = 0}) async {
    _timer?.cancel();
    _bout = bout;
    _decelerationStart = null;
    _decelerationStartRpm = null;
    final incremental = protocol == TestProtocol.incremental;
    _session.value = TestSession(
      protocol: protocol,
      phase: TestPhase.armed,
      stageIndex: incremental ? 0 : null,
      stageCount: incremental ? incrementalStagesRpm.length : null,
      targetCadenceRpm: incremental ? incrementalStagesRpm.first : null,
    );
    _timer = Timer(_armDelay, () {
      _update((s) => s.copyWith(phase: TestPhase.running, heartRateBpm: 75));
      _timer = Timer.periodic(_tick, (_) => _onTick());
    });
  }

  @override
  Future<void> stop() async {
    final s = _session.value;
    if (s == null) return;
    if (s.phase == TestPhase.armed) return abort();
    if (s.phase == TestPhase.running) {
      _update((s) => s.copyWith(phase: TestPhase.deceleration));
    }
  }

  @override
  Future<void> abort() async {
    _timer?.cancel();
    _update((s) => s.copyWith(phase: TestPhase.aborted));
  }

  @override
  void reset() {
    _timer?.cancel();
    _session.value = null;
  }

  void _update(TestSession Function(TestSession) change) {
    final s = _session.value;
    if (s != null) _session.value = change(s);
  }

  void _onTick() {
    final s = _session.value;
    if (s == null) return;
    final elapsed = s.elapsed + _tick;

    if (s.phase == TestPhase.deceleration) {
      _decelerationTick(s, elapsed);
      return;
    }

    final p = protocolProgress(s.protocol, elapsed);
    final cadence = switch (s.protocol) {
      // Écart volontairement visible de temps en temps (« trop vite / trop lent »).
      TestProtocol.incremental => p.targetCadenceRpm! + _noise(5),
      // Accélération rapide qui plafonne vers 130 rpm.
      TestProtocol.forceVelocity => 130 * (1 - exp(-elapsed.inMilliseconds / 1000 / 1.5)),
      TestProtocol.subMaximal || TestProtocol.frictionCalibration => 90 + _noise(2),
    };
    final next = s.copyWith(
      elapsed: elapsed,
      cadenceRpm: cadence,
      stageIndex: p.stageIndex,
      targetCadenceRpm: p.targetCadenceRpm,
      stageRemaining: p.stageRemaining,
      remaining: p.remaining,
      phase: p.shouldStop ? TestPhase.deceleration : null,
    );
    final heartRate = _heartRate(elapsed);
    _session.value = next.copyWith(
      heartRateBpm: heartRate,
      samples: next.phase == TestPhase.running
          ? [
              ...next.samples,
              TestSample(
                elapsed: elapsed,
                cadenceRpm: next.cadenceRpm,
                heartRateBpm: heartRate,
                stageIndex: next.stageIndex,
                targetCadenceRpm: next.targetCadenceRpm,
              ),
            ]
          : null,
    );
  }

  /// Le volant ralentit à vitesse constante (avec un peu de bruit de mesure).
  /// Quand il s'arrête, on ajuste une droite sur la courbe : sa pente est la
  /// décélération, qui donnera la force de friction.
  void _decelerationTick(TestSession s, Duration elapsed) {
    _decelerationStart ??= elapsed - _tick;
    _decelerationStartRpm ??= s.cadenceRpm ?? 0;
    final t = (elapsed - _decelerationStart!).inMilliseconds / 1000;
    final speed = _decelerationStartRpm! - _deceleration * t;

    if (speed <= 0) {
      _timer?.cancel();
      _decelerationStart = null;
      _decelerationStartRpm = null;
      final fit = fitLine(s.decelerationCurve);
      _session.value = s.copyWith(
        phase: TestPhase.finished,
        cadenceRpm: 0,
        elapsed: elapsed,
        decelerationSlope: fit?.slope,
        decelerationR2: fit?.r2,
      );
      return;
    }
    final measured = speed + _noise(0.4);
    _session.value = s.copyWith(
      cadenceRpm: measured,
      elapsed: elapsed,
      decelerationCurve: [...s.decelerationCurve, (t, measured)],
    );
  }

  int _heartRate(Duration elapsed) {
    final minutes = elapsed.inMilliseconds / 60000;
    final rise = 75 + _heartRateIncreasePerBout * _bout;
    return (75 + rise * (1 - exp(-minutes / 2)) + _noise(1)).round();
  }

  double _noise(double amplitude) => (_random.nextDouble() * 2 - 1) * amplitude;

  @override
  void dispose() {
    _timer?.cancel();
    _session.dispose();
  }
}
