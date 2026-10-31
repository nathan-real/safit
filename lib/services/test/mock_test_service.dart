import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/test_protocol.dart';
import '../../models/test_session.dart';
import 'test_data_service.dart';

/// Test simulé, avec des valeurs plausibles pour chaque protocole.
class MockTestService implements TestDataService {
  static const _tick = Duration(milliseconds: 250);

  /// Délai simulé avant le passage des premiers traits.
  static const _armDelay = Duration(seconds: 2);

  /// Paliers du test incrémental (rpm), environ 1 min chacun.
  static const incrementalStages = [40.0, 50.0, 60.0, 70.0, 80.0];
  static const _stageDuration = Duration(minutes: 1);

  /// Pente de ralentissement simulée pendant la décélération (rpm/s).
  static const _decelerationRpmPerSecond = 12.0;

  final _session = ValueNotifier<TestSession?>(null);
  final _random = Random();
  Timer? _timer;

  @override
  ValueListenable<TestSession?> get session => _session;

  @override
  Future<void> arm(TestProtocol protocol) async {
    _timer?.cancel();
    final incremental = protocol == TestProtocol.incremental;
    _session.value = TestSession(
      protocol: protocol,
      phase: TestPhase.armed,
      stageIndex: incremental ? 0 : null,
      stageCount: incremental ? incrementalStages.length : null,
      targetCadenceRpm: incremental ? incrementalStages.first : null,
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
      final cadence = (s.cadenceRpm ?? 0) -
          _decelerationRpmPerSecond * _tick.inMilliseconds / 1000;
      if (cadence <= 0) {
        _timer?.cancel();
        _session.value = s.copyWith(phase: TestPhase.finished, cadenceRpm: 0, elapsed: elapsed);
      } else {
        _session.value = s.copyWith(cadenceRpm: cadence, elapsed: elapsed);
      }
      return;
    }

    final next = switch (s.protocol) {
      TestProtocol.incremental => _incrementalTick(s, elapsed),
      TestProtocol.subMaximal => _steadyTick(s, elapsed, 90, const Duration(minutes: 5)),
      TestProtocol.frictionCalibration => _steadyTick(s, elapsed, 90, const Duration(seconds: 5)),
      TestProtocol.forceVelocity => _sprintTick(s, elapsed),
    };
    _session.value = next.copyWith(heartRateBpm: _heartRate(elapsed));
  }

  TestSession _steadyTick(TestSession s, Duration elapsed, double cadence, Duration length) {
    final remaining = length - elapsed;
    return s.copyWith(
      elapsed: elapsed,
      cadenceRpm: cadence + _noise(2),
      remaining: remaining.isNegative ? Duration.zero : remaining,
      phase: elapsed >= length ? TestPhase.deceleration : null,
    );
  }

  TestSession _incrementalTick(TestSession s, Duration elapsed) {
    final stage = elapsed.inMilliseconds ~/ _stageDuration.inMilliseconds;
    if (stage >= incrementalStages.length) {
      return s.copyWith(elapsed: elapsed, phase: TestPhase.deceleration);
    }
    final target = incrementalStages[stage];
    return s.copyWith(
      elapsed: elapsed,
      stageIndex: stage,
      targetCadenceRpm: target,
      stageRemaining: _stageDuration * (stage + 1) - elapsed,
      // Écart volontairement visible de temps en temps (« trop vite / trop lent »).
      cadenceRpm: target + _noise(5),
    );
  }

  TestSession _sprintTick(TestSession s, Duration elapsed) {
    final t = elapsed.inMilliseconds / 1000;
    // Accélération rapide qui plafonne vers 130 rpm.
    final cadence = 130 * (1 - exp(-t / 1.5));
    return s.copyWith(
      elapsed: elapsed,
      cadenceRpm: cadence,
      phase: t >= 7 ? TestPhase.deceleration : null,
    );
  }

  int _heartRate(Duration elapsed) {
    final minutes = elapsed.inMilliseconds / 60000;
    return (75 + 75 * (1 - exp(-minutes / 2)) + _noise(1)).round();
  }

  double _noise(double amplitude) => (_random.nextDouble() * 2 - 1) * amplitude;

  @override
  void dispose() {
    _timer?.cancel();
    _session.dispose();
  }
}
