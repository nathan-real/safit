import 'package:flutter/foundation.dart';

import '../../models/camera_state.dart';
import 'camera_service.dart';

/// Caméra simulée : 240 fps, 8 marqueurs, signal stable.
class MockCameraService implements CameraService {
  MockCameraService({bool startReady = true}) {
    if (startReady) _state.value = _ready;
  }

  static const _ready = CameraState(
    status: CameraStatus.ready,
    fps: 240,
    markersDetected: 8,
    signalStable: true,
  );

  final _state = ValueNotifier(const CameraState());

  @override
  ValueListenable<CameraState> get state => _state;

  @override
  Future<void> runDetectionCheck() async {
    _state.value = const CameraState(status: CameraStatus.checking);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _state.value = _ready;
  }

  @override
  void dispose() => _state.dispose();
}
