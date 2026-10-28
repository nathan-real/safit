import 'dart:collection';

/// Régularité des images reçues, calculée à partir de leurs horodatages.
class FrameStats {
  FrameStats({required this.nominalFps});

  /// Fréquence demandée à la caméra.
  final double nominalFps;

  int frames = 0;

  /// Images manquantes, déduites des trous entre deux horodatages.
  int droppedFrames = 0;

  /// Plus grand écart observé entre deux images (ms).
  double maxGapMs = 0;

  int? _last;
  final _lastSecond = ListQueue<int>();

  double get _nominalNs => 1e9 / nominalFps;

  void add(int timestampNs) {
    final last = _last;
    if (last != null) {
      final gap = timestampNs - last;
      if (gap > 1.5 * _nominalNs) {
        droppedFrames += (gap / _nominalNs).round() - 1;
      }
      if (gap / 1e6 > maxGapMs) maxGapMs = gap / 1e6;
    }
    _last = timestampNs;
    frames++;

    _lastSecond.add(timestampNs);
    while (timestampNs - _lastSecond.first > 1000000000) {
      _lastSecond.removeFirst();
    }
  }

  /// Images réellement reçues par seconde, sur la dernière seconde.
  double get fps {
    if (_lastSecond.length < 2) return 0;
    return (_lastSecond.length - 1) * 1e9 / (_lastSecond.last - _lastSecond.first);
  }
}
