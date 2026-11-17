import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safit/models/ergocycle_parameters.dart';
import 'package:safit/models/test_protocol.dart';
import 'package:safit/models/test_session.dart';
import 'package:safit/services/ble/mock_heart_rate_service.dart';
import 'package:safit/services/camera/high_speed_channel.dart';
import 'package:safit/services/test/real_test_service.dart';

const _fps = 240;
const _frameNs = 1000000000 ~/ _fps;

/// Faux canal caméra : on lui fait envoyer les images à la main.
class _FakeChannel implements HighSpeedCameraChannel {
  Rect? roi = const Rect.fromLTWH(0.2, 0.4, 0.6, 0.15);
  bool started = false;
  bool stopped = false;
  final _samples = StreamController<SampleBatch>.broadcast(sync: true);

  @override
  Stream<SampleBatch> get samples => _samples.stream;

  @override
  Future<Rect?> loadRoi() async => roi;

  @override
  Future<HighSpeedSession> start(Rect roi) async {
    started = true;
    return HighSpeedSession.fromMap({
      'textureId': 1,
      'previewWidth': 720,
      'previewHeight': 1280,
      'captureWidth': 1280,
      'captureHeight': 720,
      'fps': _fps,
      'highSpeed': true,
      'cameraId': '0',
      'sensorOrientation': 90,
      'highSpeedOptions': <String>[],
    });
  }

  @override
  Future<void> stop() async => stopped = true;

  void send(List<int> t, List<double> y) => _samples.add(SampleBatch.fromMap({
        't': Int64List.fromList(t),
        'y': Float32List.fromList(y),
        'sensorFrames': -1,
        'encodedFrames': -1,
        'lastEncodedNs': -1,
      }));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Volant à [cadence] tr/min (côté pédale) pendant [steady] s, puis ralentissement
/// de [deceleration] tr/min par seconde jusqu'à l'arrêt, puis 2 s immobile.
/// Renvoie la luminosité image par image (traits noirs = 0,3 ; fond = 0,6).
List<double> _wheel({
  required double cadence,
  required double steady,
  required double deceleration,
  required ErgocycleParameters ergo,
}) {
  final marksPerRpm = ergo.flywheelTurnsPerPedalTurn * ergo.marksPerFlywheelTurn / 60;
  final stopAt = steady + cadence / deceleration;
  final total = stopAt + 2;
  var position = 0.0; // en traits
  final y = <double>[];
  for (var i = 0; i < total * _fps; i++) {
    final t = i / _fps;
    final rpm = t < steady ? cadence : max(0.0, cadence - deceleration * (t - steady));
    position += rpm * marksPerRpm / _fps;
    y.add(position % 1 < 0.3 ? 0.3 : 0.6);
  }
  return y;
}

void main() {
  late _FakeChannel channel;
  late MockHeartRateService heartRate;
  late ValueNotifier<ErgocycleParameters> ergo;
  late RealTestService service;

  setUp(() {
    channel = _FakeChannel();
    heartRate = MockHeartRateService(live: false);
    ergo = ValueNotifier(ErgocycleParameters.provisionalDefaults);
    service = RealTestService(heartRate: heartRate, ergocycle: ergo, channel: channel);
  });
  tearDown(() {
    service.dispose();
    heartRate.dispose();
    ergo.dispose();
  });

  /// Envoie le signal par lots de 50 ms, comme le téléphone.
  Future<void> play(List<double> luma, {int offsetFrames = 0}) async {
    const batch = 12;
    for (var start = 0; start < luma.length; start += batch) {
      final end = min(start + batch, luma.length);
      channel.send(
        [for (var i = start; i < end; i++) (offsetFrames + i) * _frameNs],
        luma.sublist(start, end),
      );
    }
    await pumpEventQueue();
  }

  test('Calibration réelle : départ aux traits, cadence, décélération, fin auto', () async {
    final phases = <TestPhase>[];
    service.session.addListener(() {
      final p = service.session.value?.phase;
      if (p != null && (phases.isEmpty || phases.last != p)) phases.add(p);
    });

    await service.arm(TestProtocol.frictionCalibration);
    expect(channel.started, isTrue);
    expect(service.session.value!.phase, TestPhase.armed);

    // Volant immobile au début : on reste en attente.
    await play(List.filled(_fps, 0.6));
    expect(service.session.value!.phase, TestPhase.armed);

    // 60 tr/min pendant 5,3 s puis ralentissement de 20 tr/min par seconde.
    await play(
      _wheel(cadence: 60, steady: 5.3, deceleration: 20, ergo: ergo.value),
      offsetFrames: _fps,
    );

    final s = service.session.value!;
    expect(phases, [TestPhase.armed, TestPhase.running, TestPhase.deceleration, TestPhase.finished]);
    expect(s.samples, isNotEmpty);
    final steady = s.samples.where((x) => x.elapsed > const Duration(seconds: 1)).toList();
    for (final x in steady) {
      expect(x.cadenceRpm, closeTo(60, 1));
    }
    expect(s.samples.first.heartRateBpm, isNotNull);
    expect(s.decelerationCurve.length, greaterThan(10));
    expect(s.decelerationSlope, closeTo(-20, 0.5));
    expect(s.decelerationR2, greaterThan(0.99));
    expect(channel.stopped, isTrue);
  });

  test('Sans zone de détection réglée : test annulé', () async {
    channel.roi = null;
    await service.arm(TestProtocol.forceVelocity);
    expect(service.session.value!.phase, TestPhase.aborted);
    expect(channel.started, isFalse);
  });

  test('Arrêter avant les premiers traits annule et éteint la caméra', () async {
    await service.arm(TestProtocol.incremental);
    expect(service.session.value!.targetCadenceRpm, 40);
    await service.stop();
    expect(service.session.value!.phase, TestPhase.aborted);
    expect(channel.stopped, isTrue);
  });
}
