import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MaterialApp(home: RecordPage()));
}

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  static const _channel = MethodChannel('highspeed');
  int? _textureId;
  bool _recording = false;
  int _quarterTurns = 1;
  String _status = 'Ouverture de la caméra...';

  // Variable pour stocker et déclencher l'affichage des résultats
  VideoStats? _stats;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final id = await _channel.invokeMethod<int>('open');
      setState(() {
        _textureId = id;
        _status = 'Prêt (240 ips)';
      });
    } catch (e) {
      setState(() => _status = 'Erreur : $e');
    }
  }

  Future<void> _toggle() async {
    try {
      if (!_recording) {
        setState(() => _stats = null); // Masque les anciens résultats
        await _channel.invokeMethod<String>('start');
        setState(() {
          _recording = true;
          _status = 'Enregistrement...';
        });
      } else {
        final data = await _channel.invokeMapMethod<String, dynamic>('stop');
        final path = data?['path'] as String;
        final rawTimestamps = data?['timestamps'] as List<dynamic>;
        final timestamps = rawTimestamps.cast<double>();

        setState(() {
          _recording = false;
          _status = 'Enregistré : $path';
        });

        // Pass the true data to the analysis function
        _processVideoStats(timestamps);
      }
    } catch (e) {
      setState(() => _status = 'Erreur : $e');
    }
  }

  Future<void> _processVideoStats(List<double> timestamps) async {
    if (timestamps.isNotEmpty) {
      setState(() {
        _stats = analyzeTimestamps(timestamps);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _textureId == null
                ? const CircularProgressIndicator()
                : AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Texture(textureId: _textureId!),
                  ),
          ),
          Positioned(
            left: 12,
            top: 48,
            right: 12,
            child: Text(_status, style: const TextStyle(color: Colors.white)),
          ),
          Positioned(
            right: 24,
            bottom: 48,
            child: FloatingActionButton(
              heroTag: 'rec',
              backgroundColor: _recording ? Colors.grey : Colors.red,
              onPressed: _textureId == null ? null : _toggle,
              child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
            ),
          ),

          // Calque d'affichage des statistiques
          if (_stats != null)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _stats.toString(),
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => setState(() => _stats = null),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Classes d'analyse à placer ici ---

class VideoStats {
  final int frameCount;
  final double duration;
  final double meanFps;
  final double medianIntervalMs;
  final double medianFps;
  final int largeGapsCount;
  final double maxGapMs;
  final double maxGapTimeS;
  final int missingFrames;

  VideoStats({
    required this.frameCount,
    required this.duration,
    required this.meanFps,
    required this.medianIntervalMs,
    required this.medianFps,
    required this.largeGapsCount,
    required this.maxGapMs,
    required this.maxGapTimeS,
    required this.missingFrames,
  });

  @override
  String toString() {
    return '''
Images : $frameCount
Durée : ${duration.toStringAsFixed(3)} s
FPS moyen : ${meanFps.toStringAsFixed(2)}
Inter. médian : ${medianIntervalMs.toStringAsFixed(3)} ms
FPS médian : ${medianFps.toStringAsFixed(1)}
Trous > 6 ms : $largeGapsCount
Plus grand trou : ${maxGapMs.toStringAsFixed(1)} ms 
                à t = ${maxGapTimeS.toStringAsFixed(2)} s
Images manquantes : ~$missingFrames
''';
  }
}

VideoStats analyzeTimestamps(List<double> t) {
  if (t.length < 2) throw Exception("Pas assez de données");

  t.sort();
  List<double> d = [];
  for (int i = 1; i < t.length; i++) {
    d.add(t[i] - t[i - 1]);
  }

  double duration = t.last - t.first;
  double meanFps = (t.length - 1) / duration;

  List<double> sortedD = List.from(d)..sort();
  double medianInterval = sortedD[sortedD.length ~/ 2];

  int largeGapsCount = 0;
  double maxGap = 0.0;
  int maxGapIndex = 0;
  double missingFramesRaw = 0.0;

  for (int i = 0; i < d.length; i++) {
    double gap = d[i];
    if (gap > 0.006) {
      largeGapsCount++;
      missingFramesRaw += (gap / medianInterval) - 1;
    }
    if (gap > maxGap) {
      maxGap = gap;
      maxGapIndex = i;
    }
  }

  return VideoStats(
    frameCount: t.length,
    duration: duration,
    meanFps: meanFps,
    medianIntervalMs: medianInterval * 1000,
    medianFps: 1 / medianInterval,
    largeGapsCount: largeGapsCount,
    maxGapMs: maxGap * 1000,
    maxGapTimeS: t[maxGapIndex],
    missingFrames: missingFramesRaw.round(),
  );
}
