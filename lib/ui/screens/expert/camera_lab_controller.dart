import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../domain/signal_processing/frame_stats.dart';
import '../../../domain/signal_processing/mark_detector.dart';
import '../../../services/camera/high_speed_channel.dart';

/// Logique de l'écran « Prototype caméra » : reçoit les mesures, calcule les
/// statistiques, détecte les traits et enregistre un CSV à la demande.
class CameraLabController extends ChangeNotifier {
  CameraLabController(this._camera);

  final HighSpeedCameraChannel _camera;

  /// Durée affichée sur la courbe.
  static const chartWindowNs = 2000000000;

  HighSpeedSession? session;
  String? error;
  bool starting = false;

  Rect roi = const Rect.fromLTWH(0.2, 0.4, 0.6, 0.15);
  bool exposureLocked = false;
  int markersPerTurn = 8;

  /// Interrupteurs de diagnostic : couper l'un puis l'autre montre
  /// ce qui empêche d'atteindre la fréquence demandée.
  bool previewEnabled = true;
  bool analysisEnabled = true;

  /// Temps moyen de traitement d'une image côté natif (ms).
  double? workMs;

  FrameStats stats = FrameStats(nominalFps: 240);
  final detector = MarkDetector();
  double sensorFps = 0;
  double? lastLuma;

  /// Dernières mesures, pour la courbe : (horodatage ns, luminosité).
  final chart = ListQueue<(int, double)>();

  StreamSubscription<SampleBatch>? _subscription;
  final _sensorHistory = ListQueue<(int, int)>();

  StringBuffer? _recording;
  int recordedSamples = 0;
  String? lastSavedPath;

  bool get isRunning => session != null;
  bool get isRecording => _recording != null;

  int get lastTimestamp => chart.isEmpty ? 0 : chart.last.$1;

  /// Traits par seconde, sur la dernière seconde.
  int get marksPerSecond => detector.marksInLastSecond(lastTimestamp);

  /// Vitesse du volant déduite des traits (tours/min).
  double get wheelRpm => marksPerSecond / markersPerTurn * 60;

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
      _sensorHistory.clear();
      if (exposureLocked) await _camera.setExposureLocked(true);
      if (!previewEnabled) await _camera.setPreviewEnabled(false);
      if (!analysisEnabled) await _camera.setAnalysisEnabled(false);
    } on PlatformException catch (e) {
      error = e.message ?? e.code;
      await _subscription?.cancel();
      _subscription = null;
    } finally {
      starting = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (isRecording) await stopRecording();
    await _subscription?.cancel();
    _subscription = null;
    if (session != null) await _camera.stop();
    session = null;
    notifyListeners();
  }

  void setRoi(Rect value) {
    roi = value;
    if (isRunning) _camera.setRoi(value);
    notifyListeners();
  }

  void setExposureLocked(bool value) {
    exposureLocked = value;
    if (isRunning) _camera.setExposureLocked(value);
    notifyListeners();
  }

  void setPreviewEnabled(bool value) {
    previewEnabled = value;
    if (isRunning) _camera.setPreviewEnabled(value);
    _noteSettingsChange();
    notifyListeners();
  }

  void setAnalysisEnabled(bool value) {
    analysisEnabled = value;
    if (isRunning) _camera.setAnalysisEnabled(value);
    _noteSettingsChange();
    notifyListeners();
  }

  /// Garde une trace des changements de réglage dans le CSV en cours.
  void _noteSettingsChange() {
    _recording?.writeln('# ${lastTimestamp}ns apercu=$previewEnabled analyse=$analysisEnabled');
  }

  void setMarkersPerTurn(int value) {
    markersPerTurn = value.clamp(1, 64);
    notifyListeners();
  }

  void startRecording() {
    final s = session;
    if (s == null) return;
    final r = roi;
    _recording = StringBuffer()
      ..writeln('# SAFiT - prototype caméra')
      ..writeln('# date=${DateTime.now().toIso8601String()}')
      ..writeln('# camera=${s.cameraId} taille=${s.captureWidth}x${s.captureHeight} '
          'fps=${s.fps} haute_vitesse=${s.highSpeed}')
      ..writeln('# roi=${r.left.toStringAsFixed(3)},${r.top.toStringAsFixed(3)},'
          '${r.width.toStringAsFixed(3)},${r.height.toStringAsFixed(3)} '
          'marqueurs_par_tour=$markersPerTurn exposition_bloquee=$exposureLocked')
      ..writeln('# apercu=$previewEnabled analyse=$analysisEnabled '
          'lecture_sans_attente=${s.asyncReadback}')
      ..writeln('timestamp_ns,luminosite,trait');
    recordedSamples = 0;
    notifyListeners();
  }

  /// Écrit le fichier et renvoie son chemin.
  Future<String?> stopRecording() async {
    final buffer = _recording;
    if (buffer == null) return null;
    _recording = null;
    notifyListeners();

    final dir = await _camera.outputDirectory();
    if (dir == null) {
      error = 'Dossier de sortie introuvable';
      notifyListeners();
      return null;
    }
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('$dir/safit_camera_$stamp.csv');
    await file.writeAsString(buffer.toString());
    lastSavedPath = file.path;
    notifyListeners();
    return file.path;
  }

  void _onBatch(SampleBatch batch) {
    final recording = _recording;
    for (var i = 0; i < batch.timestampsNs.length; i++) {
      final t = batch.timestampsNs[i];
      final y = batch.luma[i];
      stats.add(t);
      if (y < 0) {
        // Analyse coupée : seule l'heure de l'image compte.
        recording?.writeln('$t,,');
        continue;
      }
      final mark = detector.add(t, y);
      chart.add((t, y));
      recording?.writeln('$t,${y.toStringAsFixed(4)},${mark ? 1 : 0}');
    }
    if (recording != null) recordedSamples += batch.timestampsNs.length;
    while (chart.isNotEmpty && chart.last.$1 - chart.first.$1 > chartWindowNs) {
      chart.removeFirst();
    }
    if (batch.luma.isNotEmpty && batch.luma.last >= 0) lastLuma = batch.luma.last;
    if (batch.workUs >= 0) workMs = batch.workUs / 1000;
    _updateSensorFps(batch.sensorFrames);
    notifyListeners();
  }

  /// Images sorties du capteur par seconde (horloge du téléphone).
  void _updateSensorFps(int sensorFrames) {
    final now = DateTime.now().microsecondsSinceEpoch;
    _sensorHistory.add((now, sensorFrames));
    while (now - _sensorHistory.first.$1 > 1000000) {
      _sensorHistory.removeFirst();
    }
    final first = _sensorHistory.first;
    final elapsed = now - first.$1;
    if (elapsed > 0) sensorFps = (sensorFrames - first.$2) * 1e6 / elapsed;
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
