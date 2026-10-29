enum CameraStatus {
  /// Zone de détection jamais réglée (mode expert).
  notConfigured,
  checking,
  ready,

  /// Pas de caméra utilisable, ou vérification ratée : voir [CameraState.message].
  error,
}

/// État de la caméra et qualité de la détection des traits.
class CameraState {
  const CameraState({
    this.status = CameraStatus.notConfigured,
    this.fps,
    this.markersDetected,
    this.signalStable = false,
    this.highSpeed = true,
    this.message,
  });

  final CameraStatus status;

  /// Fréquence d'images : mesurée pendant la vérification, sinon celle annoncée.
  final double? fps;

  /// Nombre de traits vus pendant la dernière vérification.
  final int? markersDetected;
  final bool signalStable;

  /// Faux si le téléphone n'autorise pas le mode ≈240 fps (mesures moins précises).
  final bool highSpeed;

  /// Explication à afficher (erreur, conseil).
  final String? message;

  bool get isReady => status == CameraStatus.ready;
}
