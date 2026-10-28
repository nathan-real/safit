enum CameraStatus { notConfigured, checking, ready, error }

/// État de la caméra et qualité de la détection des traits.
class CameraState {
  const CameraState({
    this.status = CameraStatus.notConfigured,
    this.fps,
    this.markersDetected,
    this.signalStable = false,
  });

  final CameraStatus status;

  /// Fréquence d'images réellement mesurée.
  final double? fps;

  /// Nombre de traits noirs vus sur un tour de volant.
  final int? markersDetected;
  final bool signalStable;

  bool get isReady => status == CameraStatus.ready;
}
