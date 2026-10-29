import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/signal_processing/frame_stats.dart';
import '../../domain/signal_processing/mark_detector.dart';
import '../../models/camera_state.dart';
import 'camera_service.dart';
import 'high_speed_channel.dart';

/// Vraie caméra (Android), à partir du prototype validé en PFE-47.
///
/// La zone de détection est celle réglée et mémorisée dans l'écran
/// « Réglage caméra » (mode expert). La vérification allume la caméra
/// quelques secondes et compte les traits qui passent.
class RealCameraService implements CameraService {
  RealCameraService({
    HighSpeedCameraChannel? channel,
    this.checkDuration = const Duration(seconds: 3),
  }) : _camera = channel ?? HighSpeedCameraChannel() {
    refresh();
  }

  final HighSpeedCameraChannel _camera;

  /// Durée pendant laquelle la caméra filme lors d'une vérification.
  final Duration checkDuration;

  /// Nombre minimal de traits pour considérer la détection fiable.
  static const minMarks = 2;

  static const _noMarksMessage =
      'Aucun trait détecté. Faites tourner le volant pendant la vérification, '
      'ou réglez la zone de détection en mode expert.';

  final _state = ValueNotifier(const CameraState(status: CameraStatus.checking));
  bool _disposed = false;

  @override
  ValueListenable<CameraState> get state => _state;

  @override
  Future<void> refresh() async {
    try {
      final description = await _camera.describe();
      if (!description.available) {
        _set(CameraState(
          status: CameraStatus.error,
          message: description.error ?? 'Aucune caméra arrière utilisable.',
        ));
        return;
      }
      final roi = await _camera.loadRoi();
      _set(CameraState(
        status: roi == null ? CameraStatus.notConfigured : CameraStatus.ready,
        fps: description.fps.toDouble(),
        highSpeed: description.highSpeed,
        message: roi == null ? 'La zone de détection n\'est pas encore réglée.' : null,
      ));
    } on MissingPluginException {
      _set(const CameraState(
        status: CameraStatus.error,
        message: 'Caméra non disponible sur cet appareil.',
      ));
    } on PlatformException catch (e) {
      _set(CameraState(status: CameraStatus.error, message: e.message ?? e.code));
    }
  }

  @override
  Future<void> runDetectionCheck() async {
    final roi = await _camera.loadRoi();
    if (roi == null) {
      await refresh();
      return;
    }
    final previous = _state.value;
    _set(CameraState(
      status: CameraStatus.checking,
      fps: previous.fps,
      highSpeed: previous.highSpeed,
    ));

    final detector = MarkDetector();
    final stats = FrameStats(nominalFps: previous.fps ?? 240);
    int? first;
    int? last;
    var sawContrast = false;
    final subscription = _camera.samples.listen((batch) {
      for (var i = 0; i < batch.timestampsNs.length; i++) {
        final t = batch.timestampsNs[i];
        first ??= t;
        last = t;
        stats.add(t);
        detector.add(t, batch.luma[i]);
        if (detector.threshold != null) sawContrast = true;
      }
    });

    final HighSpeedSession session;
    try {
      session = await _camera.start(roi);
      await Future<void>.delayed(checkDuration);
      await _camera.stop();
    } on PlatformException catch (e) {
      await subscription.cancel();
      _set(CameraState(
        status: CameraStatus.error,
        highSpeed: previous.highSpeed,
        message: e.message ?? e.code,
      ));
      return;
    }
    await subscription.cancel();

    final elapsedNs = (first != null && last != null) ? last! - first! : 0;
    final fps = elapsedNs > 0 ? (stats.frames - 1) * 1e9 / elapsedNs : 0.0;
    final ok = sawContrast && detector.marks.length >= minMarks;
    _set(CameraState(
      status: ok ? CameraStatus.ready : CameraStatus.error,
      fps: fps,
      markersDetected: detector.marks.length,
      signalStable: ok,
      highSpeed: session.highSpeed,
      message: ok ? null : _noMarksMessage,
    ));
  }

  void _set(CameraState value) {
    if (!_disposed) _state.value = value;
  }

  @override
  void dispose() {
    _disposed = true;
    _state.dispose();
  }
}
