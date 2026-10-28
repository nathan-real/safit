import 'dart:collection';

/// Repère le passage des traits noirs dans le signal de luminosité.
///
/// Le seuil s'adapte tout seul : il se place au milieu entre le plus sombre
/// et le plus clair vus pendant la dernière [window]. Une hystérésis évite de
/// compter deux fois le même trait quand le signal est bruité.
class MarkDetector {
  MarkDetector({
    this.window = const Duration(milliseconds: 1500),
    this.hysteresis = 0.15,
    this.minContrast = 0.04,
  });

  final Duration window;

  /// Écart autour du seuil, en fraction de l'amplitude (0.15 = ±15 %).
  final double hysteresis;

  /// Amplitude minimale (sur 0..1) pour considérer qu'il y a des traits.
  final double minContrast;

  final _recent = ListQueue<(int, double)>();
  bool _inMark = false;
  double? _low;
  double? _high;

  /// Horodatage (ns) du début de chaque trait détecté.
  final List<int> marks = [];

  /// Seuil courant, ou null si le signal est trop plat.
  double? get threshold => _low == null ? null : (_low! + _high!) / 2;

  /// Ajoute une mesure ; renvoie vrai si un nouveau trait commence.
  bool add(int timestampNs, double luma) {
    _recent.add((timestampNs, luma));
    final cutoff = timestampNs - window.inMicroseconds * 1000;
    while (_recent.first.$1 < cutoff) {
      _recent.removeFirst();
    }

    var min = luma;
    var max = luma;
    for (final (_, y) in _recent) {
      if (y < min) min = y;
      if (y > max) max = y;
    }
    final range = max - min;
    if (range < minContrast) {
      _low = _high = null;
      _inMark = false;
      return false;
    }
    _low = min + range * (0.5 - hysteresis);
    _high = min + range * (0.5 + hysteresis);

    if (!_inMark && luma < _low!) {
      _inMark = true;
      marks.add(timestampNs);
      return true;
    }
    if (_inMark && luma > _high!) _inMark = false;
    return false;
  }

  /// Nombre de traits vus pendant la seconde précédant [nowNs].
  int marksInLastSecond(int nowNs) {
    var n = 0;
    for (var i = marks.length - 1; i >= 0 && nowNs - marks[i] <= 1000000000; i--) {
      n++;
    }
    return n;
  }

  void reset() {
    _recent.clear();
    marks.clear();
    _inMark = false;
    _low = _high = null;
  }
}
