import 'package:flutter/foundation.dart';

import '../../models/camera_state.dart';

/// Accès à la caméra haute fréquence qui détecte les traits du volant.
/// Implémentations : [MockCameraService], puis la vraie version native.
abstract interface class CameraService {
  ValueListenable<CameraState> get state;

  /// Vérifie que les traits sont bien vus dans la zone de détection.
  Future<void> runDetectionCheck();
  void dispose();
}
