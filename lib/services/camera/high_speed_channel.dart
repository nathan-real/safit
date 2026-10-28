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
        highSpeedOptions = (m['highSpeedOptions'] as List).cast<String>();

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
}

/// Lot de mesures envoyé environ toutes les 50 ms.
class SampleBatch {
  SampleBatch.fromMap(Map<Object?, Object?> m)
      : timestampsNs = m['t'] as Int64List,
        luma = m['y'] as Float32List,
        sensorFrames = m['sensorFrames'] as int,
        encodedFrames = m['encodedFrames'] as int,
        lastEncodedNs = m['lastEncodedNs'] as int;

  /// Horodatage capteur de chaque image analysée (nanosecondes).
  final Int64List timestampsNs;

  /// Luminosité moyenne de la zone de détection (0 = noir, 1 = blanc).
  final Float32List luma;

  /// Total d'images sorties du capteur depuis le démarrage (-1 si inconnu).
  final int sensorFrames;

  /// Total d'images vidéo encodées (-1 si inconnu).
  final int encodedFrames;

  /// Horodatage de la dernière image vidéo encodée (-1 si inconnu) :
  /// l'écart avec la dernière image analysée donne le retard de l'analyse.
  final int lastEncodedNs;
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

  /// Arrête la caméra ; se termine quand toutes les images filmées sont analysées.
  Future<void> stop() => _methods.invokeMethod('stop');

  Future<void> setRoi(Rect roi) => _methods.invokeMethod('setRoi', _roiArgs(roi));

  Future<void> setExposureLocked(bool locked) =>
      _methods.invokeMethod('setExposureLocked', locked);

  /// Commence à enregistrer la vidéo ; renvoie le chemin du futur fichier MP4.
  Future<String?> startRecording() => _methods.invokeMethod<String>('startRecording');

  /// Termine la vidéo ; renvoie son chemin (null si rien n'a été écrit).
  Future<String?> stopRecording() => _methods.invokeMethod<String>('stopRecording');

  /// Dossier où enregistrer les fichiers de mesures, accessible en USB
  /// (Android/data/fr.ensc.safit/files).
  Future<String?> outputDirectory() => _methods.invokeMethod<String>('outputDirectory');

  static List<double> _roiArgs(Rect r) => [r.left, r.top, r.width, r.height];
}
