import 'package:flutter/foundation.dart';

import '../../models/camera_state.dart';

/// Accès à la caméra haute fréquence qui détecte les traits du volant.
/// Implémentations : [MockCameraService] et [RealCameraService].
abstract interface class CameraService {
  ValueListenable<CameraState> get state;

  /// Relit l'état de la caméra (après un réglage en mode expert, par exemple).
  Future<void> refresh();

  /// Vérifie que les traits sont bien vus dans la zone de détection.
  Future<void> runDetectionCheck();
  void dispose();
}
