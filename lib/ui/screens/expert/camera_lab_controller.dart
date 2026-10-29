import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../domain/signal_processing/frame_stats.dart';
import '../../../domain/signal_processing/mark_detector.dart';
import '../../../services/camera/high_speed_channel.dart';

/// Logique de l'écran « Prototype caméra » : reçoit les mesures, calcule les
/// statistiques, détecte les traits et enregistre vidéo + CSV à la demande.
class CameraLabController extends ChangeNotifier {
  CameraLabController(this._camera);

  final HighSpeedCameraChannel _camera;

  /// Durée affichée sur la courbe.
  static const chartWindowNs = 2000000000;

  HighSpeedSession? session;
  String? error;
  bool starting = false;

  /// Vrai pendant l'arrêt : la caméra est coupée, l'analyse finit les dernières images.
  bool stopping = false;

  Rect roi = const Rect.fromLTWH(0.2, 0.4, 0.6, 0.15);
  bool exposureLocked = false;
  int markersPerTurn = 8;

  FrameStats stats = FrameStats(nominalFps: 240);
  final detector = MarkDetector();
  double sensorFps = 0;
  double videoFps = 0;

  /// Retard de l'analyse sur la vidéo (ms) : proche de 0 = analyse en temps réel.
  double analysisLagMs = 0;

  /// Dernières mesures, pour la courbe : (horodatage ns, luminosité).
  final chart = ListQueue<(int, double)>();

  StreamSubscription<SampleBatch>? _subscription;
  final _counterHistory = ListQueue<(int, int, int)>();
  int _lastAnalyzedNs = 0;

  StringBuffer? _recording;
  String? _recordingVideoPath;
  int recordedSamples = 0;
  List<String> lastSavedPaths = [];

  bool get isRunning => session != null;
  bool get isRecording => _recording != null;

  /// Nombre d'intervalles entre traits utilisés pour les moyennes affichées.
  static const intervalWindow = 8;

  /// Intervalle moyen entre deux traits (ms), sur les derniers traits.
  double? get meanIntervalMs {
    final intervals = detector.recentIntervals(intervalWindow);
    if (intervals.isEmpty) return null;
    return intervals.reduce((a, b) => a + b) / intervals.length / 1e6;
  }

  /// Écart-type des intervalles (ms) : mesure la régularité, donc la précision.
  double? get intervalSpreadMs {
    final intervals = detector.recentIntervals(intervalWindow);
    if (intervals.length < 2) return null;
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals.map((i) => (i - mean) * (i - mean)).reduce((a, b) => a + b) /
        (intervals.length - 1);
    return sqrt(variance) / 1e6;
  }

  /// Vitesse du volant (tours/min), d'après l'intervalle moyen entre traits.
  double? get wheelRpm {
    final interval = meanIntervalMs;
    if (interval == null || interval <= 0) return null;
    return 60000 / (interval * markersPerTurn);
  }

  Future<void> start() async {
    starting = true;
    error = null;
    notifyListeners();
    try {
      _subscription = _camera.samples.listen(_onBatch, onError: _onStreamError);
      final s = await _camera.start(roi);
      session = s;
      stats = FrameStats(nominalFps: s.fps.toDouble());
      detector.reset();
      chart.clear();
      _counterHistory.clear();
      _lastAnalyzedNs = 0;
      if (exposureLocked) await _camera.setExposureLocked(true);
    } on PlatformException catch (e) {
      error = e.message ?? e.code;
      await _subscription?.cancel();
      _subscription = null;
    } finally {
      starting = false;
      notifyListeners();
    }
  }

  /// Coupe la caméra, attend la fin de l'analyse, puis écrit le CSV si besoin.
  Future<void> stop() async {
    if (session == null || stopping) return;
    stopping = true;
    notifyListeners();
    try {
      await _camera.stop();
    } on PlatformException catch (e) {
      error = e.message ?? e.code;
    }
    // La vidéo a été terminée par l'arrêt ; il reste le CSV.
    if (isRecording) await _saveCsv(_recordingVideoPath);
    await _subscription?.cancel();
    _subscription = null;
    session = null;
    stopping = false;
    notifyListeners();
  }

  /// Reprend la zone de détection mémorisée sur le téléphone, s'il y en a une.
  Future<void> loadSavedRoi() async {
    try {
      final saved = await _camera.loadRoi();
      if (saved != null) {
        roi = saved;
        notifyListeners();
      }
    } on MissingPluginException {
      // Pas de caméra native (tests, autre plateforme) : on garde la zone par défaut.
    }
  }

  /// Déplace la zone de détection et la mémorise : elle servira à chaque test.
  void setRoi(Rect value) {
    roi = value;
    if (isRunning) _camera.setRoi(value);
    _camera.saveRoi(value);
    notifyListeners();
  }

  void setExposureLocked(bool value) {
    exposureLocked = value;
    if (isRunning) _camera.setExposureLocked(value);
    notifyListeners();
  }

  void setMarkersPerTurn(int value) {
    markersPerTurn = value.clamp(1, 64);
    notifyListeners();
  }

  /// Démarre l'enregistrement de la vidéo et du CSV des mesures.
  Future<void> startRecording() async {
    final s = session;
    if (s == null || isRecording) return;
    final r = roi;
    _recordingVideoPath = await _camera.startRecording();
    _recording = StringBuffer()
      ..writeln('# SAFiT - prototype caméra (vidéo + analyse de chaque image)')
      ..writeln('# date=${DateTime.now().toIso8601String()}')
      ..writeln('# camera=${s.cameraId} taille=${s.captureWidth}x${s.captureHeight} '
          'fps=${s.fps} haute_vitesse=${s.highSpeed}')
      ..writeln('# roi=${r.left.toStringAsFixed(3)},${r.top.toStringAsFixed(3)},'
          '${r.width.toStringAsFixed(3)},${r.height.toStringAsFixed(3)} '
          'marqueurs_par_tour=$markersPerTurn exposition_bloquee=$exposureLocked')
      ..writeln('# video=${_recordingVideoPath ?? '-'}')
      ..writeln('# instant_trait_ns : instant du passage sous le seuil, interpolé entre deux images')
      ..writeln('timestamp_ns,luminosite,trait,instant_trait_ns');
    recordedSamples = 0;
    notifyListeners();
  }

  /// Termine la vidéo et écrit le CSV ; renvoie les chemins des fichiers.
  Future<List<String>> stopRecording() async {
    if (!isRecording) return const [];
    final video = await _camera.stopRecording();
    return _saveCsv(video);
  }

  Future<List<String>> _saveCsv(String? videoPath) async {
    final buffer = _recording;
    _recording = null;
    _recordingVideoPath = null;
    if (buffer == null) return const [];

    final dir = await _camera.outputDirectory();
    if (dir == null) {
      error = 'Dossier de sortie introuvable';
      notifyListeners();
      return const [];
    }
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('$dir/safit_camera_$stamp.csv');
    await file.writeAsString(buffer.toString());
    lastSavedPaths = [file.path, ?videoPath];
    notifyListeners();
    return lastSavedPaths;
  }

  void _onBatch(SampleBatch batch) {
    final recording = _recording;
    for (var i = 0; i < batch.timestampsNs.length; i++) {
      final t = batch.timestampsNs[i];
      final y = batch.luma[i];
      stats.add(t);
      final mark = detector.add(t, y);
      chart.add((t, y));
      recording?.writeln(
        mark ? '$t,${y.toStringAsFixed(4)},1,${detector.marks.last}' : '$t,${y.toStringAsFixed(4)},0,',
      );
      _lastAnalyzedNs = t;
    }
    if (recording != null) recordedSamples += batch.timestampsNs.length;
    while (chart.isNotEmpty && chart.last.$1 - chart.first.$1 > chartWindowNs) {
      chart.removeFirst();
    }
    if (batch.lastEncodedNs > 0 && _lastAnalyzedNs > 0) {
      analysisLagMs = (batch.lastEncodedNs - _lastAnalyzedNs) / 1e6;
    }
    _updateCounters(batch.sensorFrames, batch.encodedFrames);
    notifyListeners();
  }

  /// Images capteur et images vidéo par seconde (horloge du téléphone).
  void _updateCounters(int sensorFrames, int encodedFrames) {
    if (sensorFrames < 0 || encodedFrames < 0) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    _counterHistory.add((now, sensorFrames, encodedFrames));
    while (now - _counterHistory.first.$1 > 1000000) {
      _counterHistory.removeFirst();
    }
    final (t0, sensor0, encoded0) = _counterHistory.first;
    final elapsed = now - t0;
    if (elapsed > 0) {
      sensorFps = (sensorFrames - sensor0) * 1e6 / elapsed;
      videoFps = (encodedFrames - encoded0) * 1e6 / elapsed;
    }
  }

  void _onStreamError(Object e) {
    error = e is PlatformException ? (e.message ?? e.code) : e.toString();
    stop();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
