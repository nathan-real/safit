import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Session caméra ouverte côté natif (voir HighSpeedCameraPlugin.kt).
class HighSpeedSession {
  HighSpeedSession.fromMap(Map<Object?, Object?> m)
      : textureId = m['textureId'] as int,
        previewWidth = m['previewWidth'] as int,
        previewHeight = m['previewHeight'] as int,
        captureWidth = m['captureWidth'] as int,
        captureHeight = m['captureHeight'] as int,
        fps = m['fps'] as int,
        highSpeed = m['highSpeed'] as bool,
        cameraId = m['cameraId'] as String,
        sensorOrientation = m['sensorOrientation'] as int,
        highSpeedOptions = (m['highSpeedOptions'] as List).cast<String>(),
        asyncReadback = m['asyncReadback'] as bool;

  /// Texture Flutter où s'affiche l'aperçu.
  final int textureId;
  final int previewWidth;
  final int previewHeight;
  final int captureWidth;
  final int captureHeight;

  /// Fréquence demandée à la caméra.
  final int fps;

  /// Vrai si la session « haute vitesse » a pu être ouverte.
  final bool highSpeed;
  final String cameraId;
  final int sensorOrientation;

  /// Modes haute vitesse proposés par le téléphone, ex. « 1280x720@240 ».
  final List<String> highSpeedOptions;

  /// Vrai si le résultat du GPU est lu sans l'attendre (OpenGL ES 3).
  final bool asyncReadback;
}

/// Lot de mesures envoyé environ toutes les 50 ms.
class SampleBatch {
  SampleBatch.fromMap(Map<Object?, Object?> m)
      : timestampsNs = m['t'] as Int64List,
        luma = m['y'] as Float32List,
        sensorFrames = m['sensorFrames'] as int,
        workUs = m['workUs'] as int;

  /// Horodatage capteur de chaque image (nanosecondes).
  final Int64List timestampsNs;

  /// Luminosité moyenne de la zone de détection (0 = noir, 1 = blanc),
  /// ou une valeur négative si l'analyse est coupée.
  final Float32List luma;

  /// Total d'images sorties du capteur depuis le démarrage.
  final int sensorFrames;

  /// Temps moyen de traitement d'une image côté natif (µs), ou -1.
  final int workUs;
}

/// Accès à la caméra haute fréquence (Android uniquement pour l'instant).
class HighSpeedCameraChannel {
  static const _methods = MethodChannel('safit/highspeed');
  static const _events = EventChannel('safit/highspeed/samples');

  Stream<SampleBatch> get samples => _events
      .receiveBroadcastStream()
      .map((m) => SampleBatch.fromMap(m as Map<Object?, Object?>));

  /// [roi] : zone de détection en coordonnées de l'aperçu (0..1).
  Future<HighSpeedSession> start(Rect roi) async {
    final result = await _methods.invokeMapMethod<Object?, Object?>(
      'start',
      {'roi': _roiArgs(roi)},
    );
    return HighSpeedSession.fromMap(result!);
  }

  Future<void> stop() => _methods.invokeMethod('stop');

  Future<void> setRoi(Rect roi) => _methods.invokeMethod('setRoi', _roiArgs(roi));

  Future<void> setExposureLocked(bool locked) =>
      _methods.invokeMethod('setExposureLocked', locked);

  /// Diagnostic : coupe l'affichage de l'aperçu.
  Future<void> setPreviewEnabled(bool enabled) =>
      _methods.invokeMethod('setPreviewEnabled', enabled);

  /// Diagnostic : coupe l'analyse (on ne garde que l'heure de chaque image).
  Future<void> setAnalysisEnabled(bool enabled) =>
      _methods.invokeMethod('setAnalysisEnabled', enabled);

  /// Dossier où enregistrer les fichiers de mesures, accessible en USB
  /// (Android/data/fr.ensc.safit/files).
  Future<String?> outputDirectory() => _methods.invokeMethod<String>('outputDirectory');

  static List<double> _roiArgs(Rect r) => [r.left, r.top, r.width, r.height];
}
