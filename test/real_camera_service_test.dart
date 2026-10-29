import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safit/models/camera_state.dart';
import 'package:safit/services/camera/high_speed_channel.dart';
import 'package:safit/services/camera/real_camera_service.dart';

const _frameNs = 1000000000 ~/ 240;

/// Faux canal : remplace le côté Android (HighSpeedCameraPlugin.kt).
/// À l'allumage, il envoie [signal] comme si la caméra filmait.
class _FakeChannel implements HighSpeedCameraChannel {
  Rect? savedRoi = const Rect.fromLTWH(0.2, 0.4, 0.6, 0.15);
  bool highSpeed = true;
  bool missingPlugin = false;
  SampleBatch? signal;

  final _samples = StreamController<SampleBatch>.broadcast();

  @override
  Stream<SampleBatch> get samples => _samples.stream;

  @override
  Future<CameraDescription> describe() async {
    if (missingPlugin) throw MissingPluginException();
    return CameraDescription.fromMap({
      'available': true,
      'highSpeed': highSpeed,
      'fps': highSpeed ? 240 : 30,
    });
  }

  @override
  Future<Rect?> loadRoi() async => savedRoi;

  @override
  Future<HighSpeedSession> start(Rect roi) async {
    final s = signal;
    if (s != null) scheduleMicrotask(() => _samples.add(s));
    return HighSpeedSession.fromMap({
      'textureId': 1,
      'previewWidth': 720,
      'previewHeight': 1280,
      'captureWidth': 1280,
      'captureHeight': 720,
      'fps': 240,
      'highSpeed': highSpeed,
      'cameraId': '0',
      'sensorOrientation': 90,
      'highSpeedOptions': <String>[],
    });
  }

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [seconds] de mesures à 240 i/s, avec [marksPerSecond] traits par seconde.
SampleBatch _signal({required double seconds, required double marksPerSecond}) {
  final n = (seconds * 240).round();
  final t = Int64List(n);
  final y = Float32List(n);
  for (var i = 0; i < n; i++) {
    t[i] = i * _frameNs;
    final phase = (i / 240 * marksPerSecond) % 1;
    y[i] = marksPerSecond == 0 ? 0.6 : (phase < 0.3 ? 0.3 : 0.6);
  }
  return SampleBatch.fromMap(
    {'t': t, 'y': y, 'sensorFrames': n, 'encodedFrames': n, 'lastEncodedNs': t.last},
  );
}

void main() {
  late _FakeChannel channel;
  late RealCameraService service;

  setUp(() {
    channel = _FakeChannel();
    service = RealCameraService(channel: channel, checkDuration: Duration.zero);
  });
  tearDown(() => service.dispose());

  test('Zone réglée : la caméra est prête', () async {
    await service.refresh();
    expect(service.state.value.status, CameraStatus.ready);
    expect(service.state.value.fps, 240);
    expect(service.state.value.highSpeed, isTrue);
  });

  test('Zone jamais réglée : il faut passer par le réglage', () async {
    channel.savedRoi = null;
    await service.refresh();
    expect(service.state.value.status, CameraStatus.notConfigured);
  });

  test('Pas de 240 fps : la caméra reste utilisable, avec un avertissement', () async {
    channel.highSpeed = false;
    await service.refresh();
    expect(service.state.value.status, CameraStatus.ready);
    expect(service.state.value.highSpeed, isFalse);
  });

  test('La vérification compte les traits qui passent', () async {
    channel.signal = _signal(seconds: 3, marksPerSecond: 5);
    await service.refresh();
    await service.runDetectionCheck();

    final state = service.state.value;
    expect(state.status, CameraStatus.ready);
    expect(state.markersDetected, inInclusiveRange(14, 16));
    expect(state.signalStable, isTrue);
    expect(state.fps, closeTo(240, 1));
  });

  test('Sans traits, la vérification échoue avec une explication', () async {
    channel.signal = _signal(seconds: 3, marksPerSecond: 0);
    await service.refresh();
    await service.runDetectionCheck();

    final state = service.state.value;
    expect(state.status, CameraStatus.error);
    expect(state.markersDetected, 0);
    expect(state.message, contains('Aucun trait'));
  });

  test('Sans caméra native (autre plateforme), l\'erreur est claire', () async {
    channel.missingPlugin = true;
    await service.refresh();
    expect(service.state.value.status, CameraStatus.error);
    expect(service.state.value.message, isNotNull);
  });
}
