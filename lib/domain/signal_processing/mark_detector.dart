import 'dart:collection';
import 'dart:math';

/// Repère le passage des traits noirs dans le signal de luminosité.
///
/// Le seuil s'adapte tout seul : il se place au milieu entre le plus sombre
/// et le plus clair vus pendant la dernière [window]. Une hystérésis évite de
/// compter deux fois le même trait quand le signal est bruité.
///
/// L'instant d'un trait est celui où le signal descend sous le seuil. On ne
/// prend pas l'heure d'une image : on ajuste une droite sur toutes les images
/// de la descente (front du trait) et on calcule où elle croise le seuil.
/// C'est plus précis, même quand des images manquent pendant le passage.
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

  /// Instant (ns) du début de chaque trait détecté.
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
      final top = min + range * edgeTop;
      marks.add(_edgeCrossing(threshold!, top) ?? _bracketCrossing(threshold!) ?? timestampNs);
      return true;
    }
    if (_inMark && luma > _high!) _inMark = false;
    return false;
  }

  /// Haut du front pris en compte pour l'ajustement (fraction de l'amplitude) :
  /// on ignore le tout début de la descente, encore mêlé au plateau clair.
  static const edgeTop = 0.85;

  /// Ajuste une droite (moindres carrés) sur les mesures du front descendant,
  /// de la dernière mesure jusqu'au haut du front, et renvoie l'instant où elle
  /// croise [level]. Null s'il y a trop peu de points.
  int? _edgeCrossing(double level, double top) {
    final samples = _recent.toList(growable: false);
    final origin = samples.last.$1;
    var n = 0;
    var sumT = 0.0, sumY = 0.0, sumTT = 0.0, sumTY = 0.0;
    for (var i = samples.length - 1; i >= 0; i--) {
      final (t, y) = samples[i];
      if (y > top) break;
      // Temps relatif en ms : évite de perdre en précision sur de grands nombres.
      final x = (t - origin) / 1e6;
      n++;
      sumT += x;
      sumY += y;
      sumTT += x * x;
      sumTY += x * y;
    }
    if (n < 3) return null;
    final denominator = n * sumTT - sumT * sumT;
    if (denominator == 0) return null;
    final slope = (n * sumTY - sumT * sumY) / denominator;
    if (slope >= 0) return null;
    final intercept = (sumY - slope * sumT) / n;
    return origin + ((level - intercept) / slope * 1e6).round();
  }

  /// Solution de secours : interpolation entre les deux mesures qui encadrent
  /// le dernier passage sous [level].
  int? _bracketCrossing(double level) {
    final samples = _recent.toList(growable: false);
    for (var i = samples.length - 1; i > 0; i--) {
      final (t0, y0) = samples[i - 1];
      final (t1, y1) = samples[i];
      if (y0 >= level && y1 < level) {
        return t0 + ((y0 - level) / (y0 - y1) * (t1 - t0)).round();
      }
    }
    return null;
  }

  /// Nombre de traits vus pendant la seconde précédant [nowNs].
  int marksInLastSecond(int nowNs) {
    var n = 0;
    for (var i = marks.length - 1; i >= 0 && nowNs - marks[i] <= 1000000000; i--) {
      n++;
    }
    return n;
  }

  /// Écarts (ns) entre les traits successifs, pour les [count] derniers.
  List<int> recentIntervals(int count) {
    final start = max(1, marks.length - count);
    return [for (var i = start; i < marks.length; i++) marks[i] - marks[i - 1]];
  }

  void reset() {
    _recent.clear();
    marks.clear();
    _inMark = false;
    _low = _high = null;
  }
}
