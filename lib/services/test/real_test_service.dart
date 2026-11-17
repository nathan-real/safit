import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/protocol_timeline.dart';
import '../../domain/signal_processing/linear_fit.dart';
import '../../domain/signal_processing/mark_detector.dart';
import '../../models/ergocycle_parameters.dart';
import '../../models/test_protocol.dart';
import '../../models/test_session.dart';
import '../ble/heart_rate_service.dart';
import '../camera/high_speed_channel.dart';
import 'test_data_service.dart';

/// Vrai test : la caméra compte les traits du volant, la ceinture donne la FC.
///
/// - Armé : la caméra filme, le test démarre tout seul au 3e trait vu.
/// - Effort : cadence calculée à partir des écarts entre traits sur le dernier
///   tour de volant ; une mesure est enregistrée toutes les 250 ms.
/// - Décélération : un point de la courbe à chaque trait.
/// - Fin : plus aucun trait pendant [idleTimeout] (volant arrêté).
///
/// Le temps utilisé est celui des images de la caméra, très précis.
class RealTestService implements TestDataService {
  RealTestService({
    required this._heartRate,
    required this._ergocycle,
    HighSpeedCameraChannel? channel,
    this.idleTimeout = const Duration(milliseconds: 1500),
  }) : _camera = channel ?? HighSpeedCameraChannel();

  final HeartRateService _heartRate;
  final ValueListenable<ErgocycleParameters> _ergocycle;
  final HighSpeedCameraChannel _camera;

  /// Sans trait pendant cette durée, le volant est considéré arrêté.
  final Duration idleTimeout;

  /// Nombre de traits à voir avant de démarrer le test.
  static const startMarks = 3;
  static const _publishEveryNs = 250000000;

  /// Sans aucune image reçue pendant ce temps, la caméra s'est arrêtée.
  static const _cameraSilence = Duration(seconds: 3);

  final _session = ValueNotifier<TestSession?>(null);
  MarkDetector? _detector;
  StreamSubscription<SampleBatch>? _subscription;
  Timer? _watchdog;
  final _sinceLastBatch = Stopwatch();
  bool _cameraOn = false;

  /// Incrémenté à chaque nouveau test : ignore ce qui arrive d'un test précédent.
  int _generation = 0;

  int? _startNs;
  int? _decelerationStartNs;
  int _lastFrameNs = 0;
  int _nextPublishNs = 0;
  final _curve = <(double, double)>[];

  @override
  ValueListenable<TestSession?> get session => _session;

  @override
  bool get isSimulation => false;

  @override
  Future<void> arm(TestProtocol protocol, {int bout = 0}) async {
    await _shutdown();
    final generation = ++_generation;
    _startNs = null;
    _decelerationStartNs = null;
    _nextPublishNs = 0;
    _curve.clear();
    final first = protocolProgress(protocol, Duration.zero);
    _session.value = TestSession(
      protocol: protocol,
      phase: TestPhase.armed,
      stageIndex: first.stageIndex,
      stageCount: first.stageCount,
      targetCadenceRpm: first.targetCadenceRpm,
    );

    try {
      final roi = await _camera.loadRoi();
      if (generation != _generation) return;
      if (roi == null) {
        _update((s) => s.copyWith(phase: TestPhase.aborted));
        return;
      }
      _detector = MarkDetector();
      _subscription = _camera.samples.listen(_onBatch);
      _sinceLastBatch
        ..reset()
        ..start();
      _watchdog = Timer.periodic(const Duration(milliseconds: 500), (_) => _checkCamera());
      _cameraOn = true;
      await _camera.start(roi);
    } on PlatformException {
      if (generation == _generation) await abort();
    } on MissingPluginException {
      if (generation == _generation) await abort();
    }
  }

  @override
  Future<void> stop() async {
    final s = _session.value;
    if (s == null) return;
    if (s.phase == TestPhase.armed) return abort();
    if (s.phase == TestPhase.running) {
      _decelerationStartNs = _lastFrameNs;
      _update((s) => s.copyWith(phase: TestPhase.deceleration));
    }
  }

  @override
  Future<void> abort() async {
    await _shutdown();
    _update((s) => s.copyWith(phase: TestPhase.aborted));
  }

  @override
  void reset() {
    _generation++;
    _shutdown();
    _session.value = null;
  }

  void _update(TestSession Function(TestSession) change) {
    final s = _session.value;
    if (s != null) _session.value = change(s);
  }

  void _onBatch(SampleBatch batch) {
    final s = _session.value;
    final detector = _detector;
    if (s == null || !s.isActive || detector == null) return;
    _sinceLastBatch
      ..reset()
      ..start();

    for (var i = 0; i < batch.timestampsNs.length; i++) {
      final t = batch.timestampsNs[i];
      _lastFrameNs = t;
      if (detector.add(t, batch.luma[i])) _onMark(detector);
    }
    if (_startNs == null || detector.marks.isEmpty) return;

    final now = _lastFrameNs;
    if (now - detector.marks.last > idleTimeout.inMicroseconds * 1000) {
      _finish();
      return;
    }
    if (now >= _nextPublishNs) {
      _publish(now);
      _nextPublishNs = now + _publishEveryNs;
    }
  }

  void _onMark(MarkDetector detector) {
    final markNs = detector.marks.last;
    final s = _session.value!;
    if (s.phase == TestPhase.armed && detector.marks.length >= startMarks) {
      _startNs = detector.marks.first;
      _nextPublishNs = 0;
      _session.value = s.copyWith(
        phase: TestPhase.running,
        heartRateBpm: _heartRate.state.value.bpm,
      );
    } else if (s.phase == TestPhase.deceleration) {
      final point = _turnSpeed(detector, _decelerationStartNs ?? markNs);
      if (point != null) _curve.add(point);
    }
  }

  /// Vitesse moyenne sur le dernier tour de volant, placée au milieu de ce
  /// tour. Quand le volant ralentit régulièrement, la vitesse moyenne sur un
  /// intervalle est exactement celle du milieu de l'intervalle : la courbe
  /// reste droite, même à basse vitesse quand un tour prend longtemps.
  /// Prendre un tour entier gomme aussi les traits pas tout à fait réguliers.
  (double, double)? _turnSpeed(MarkDetector detector, int decelerationStartNs) {
    final ergo = _ergocycle.value;
    final marks = detector.marks;
    final k = ergo.marksPerFlywheelTurn;
    if (marks.length <= k) return null;
    final first = marks[marks.length - 1 - k];
    final last = marks.last;
    // Tour commencé avant l'arrêt du pédalage : il mélange effort et décélération.
    if (first < decelerationStartNs || last <= first) return null;
    final flywheelRpm = 60e9 / (last - first);
    final middle = (first + last) / 2;
    return ((middle - decelerationStartNs) / 1e9, flywheelRpm / ergo.flywheelTurnsPerPedalTurn);
  }

  /// Cadence côté pédale (tr/min), à partir des écarts entre traits sur le
  /// dernier tour de volant. Si aucun trait n'est passé depuis plus longtemps
  /// que l'écart moyen, le volant a ralenti : on prend ce temps d'attente.
  double _cadenceAt(int nowNs) {
    final ergo = _ergocycle.value;
    final detector = _detector!;
    final intervals = detector.recentIntervals(ergo.marksPerFlywheelTurn);
    if (intervals.isEmpty) return 0;
    var mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final waiting = nowNs - detector.marks.last;
    if (waiting > mean) mean = waiting.toDouble();
    final flywheelRpm = 60e9 / (mean * ergo.marksPerFlywheelTurn);
    return flywheelRpm / ergo.flywheelTurnsPerPedalTurn;
  }

  void _publish(int nowNs) {
    final s = _session.value!;
    final elapsed = Duration(microseconds: (nowNs - _startNs!) ~/ 1000);
    final cadence = _cadenceAt(nowNs);
    final heartRate = _heartRate.state.value.bpm;

    if (s.phase == TestPhase.running) {
      final p = protocolProgress(s.protocol, elapsed);
      if (p.shouldStop) _decelerationStartNs = nowNs;
      _session.value = s.copyWith(
        elapsed: elapsed,
        cadenceRpm: cadence,
        heartRateBpm: heartRate,
        stageIndex: p.stageIndex,
        targetCadenceRpm: p.targetCadenceRpm,
        stageRemaining: p.stageRemaining,
        remaining: p.remaining,
        phase: p.shouldStop ? TestPhase.deceleration : null,
        samples: p.shouldStop
            ? null
            : [
                ...s.samples,
                TestSample(
                  elapsed: elapsed,
                  cadenceRpm: cadence,
                  heartRateBpm: heartRate,
                  stageIndex: p.stageIndex,
                  targetCadenceRpm: p.targetCadenceRpm,
                ),
              ],
      );
    } else if (s.phase == TestPhase.deceleration) {
      _session.value = s.copyWith(
        elapsed: elapsed,
        cadenceRpm: cadence,
        heartRateBpm: heartRate,
        decelerationCurve: List.of(_curve),
      );
    }
  }

  /// Le volant est arrêté : on ajuste la droite de décélération et on éteint la caméra.
  void _finish() {
    final s = _session.value!;
    final curve = List.of(_curve);
    final fit = fitLine(freeWheelingPart(curve));
    _session.value = s.copyWith(
      phase: TestPhase.finished,
      cadenceRpm: 0,
      decelerationCurve: curve,
      decelerationSlope: fit?.slope,
      decelerationR2: fit?.r2,
    );
    _shutdown();
  }

  /// Plus aucune image : la caméra s'est arrêtée en cours de route.
  void _checkCamera() {
    final s = _session.value;
    if (s == null || !s.isActive || _sinceLastBatch.elapsed < _cameraSilence) return;
    if (s.phase == TestPhase.armed) return;
    _finish();
  }

  Future<void> _shutdown() async {
    _watchdog?.cancel();
    _watchdog = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    if (_cameraOn) {
      _cameraOn = false;
      try {
        await _camera.stop();
      } on PlatformException {
        // Déjà arrêtée.
      } on MissingPluginException {
        // Pas de caméra (tests).
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _shutdown();
    _session.dispose();
  }
}

/// Partie de la courbe où le volant ralentit vraiment : on retire le début,
/// où le sujet pédale encore un peu après le signal (temps de réaction),
/// jusqu'à ce que la vitesse ait baissé de 3 % par rapport au maximum.
List<(double, double)> freeWheelingPart(List<(double, double)> curve) {
  if (curve.length < 3) return curve;
  var peak = 0.0;
  for (var i = 0; i < curve.length; i++) {
    final speed = curve[i].$2;
    if (speed > peak) peak = speed;
    if (speed < peak * 0.97) return curve.sublist(max(0, i - 1));
  }
  return curve;
}
