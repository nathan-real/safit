import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:safit/domain/signal_processing/frame_stats.dart';
import 'package:safit/domain/signal_processing/mark_detector.dart';

const _frameNs = 1000000000 ~/ 240;

/// Signal simulé : volant clair (0.8), traits sombres (0.2), bruit ±0.03.
double _signal(double tSeconds, double marksPerSecond, Random random) {
  final phase = (tSeconds * marksPerSecond) % 1;
  final base = phase < 0.3 ? 0.2 : 0.8;
  return base + (random.nextDouble() - 0.5) * 0.06;
}

void main() {
  group('MarkDetector', () {
    test('compte les traits d\'un signal bruité à 240 images/s', () {
      final detector = MarkDetector();
      final random = Random(1);
      for (var i = 0; i < 240 * 3; i++) {
        detector.add(i * _frameNs, _signal(i / 240, 10, random));
      }
      // 10 traits/s pendant 3 s.
      expect(detector.marks.length, inInclusiveRange(29, 31));
      expect(detector.marksInLastSecond(240 * 3 * _frameNs), inInclusiveRange(9, 11));
    });

    test('ne voit rien sur un signal plat', () {
      final detector = MarkDetector();
      final random = Random(2);
      for (var i = 0; i < 240 * 2; i++) {
        detector.add(i * _frameNs, 0.6 + (random.nextDouble() - 0.5) * 0.02);
      }
      expect(detector.marks, isEmpty);
      expect(detector.threshold, isNull);
    });

    test('suit une décélération', () {
      final detector = MarkDetector();
      final random = Random(3);
      // La fréquence des traits passe de 20 à 5 par seconde en 4 s.
      var phase = 0.0;
      for (var i = 0; i < 240 * 4; i++) {
        final rate = 20 - 15 * (i / (240 * 4));
        phase += rate / 240;
        final base = (phase % 1) < 0.3 ? 0.2 : 0.8;
        detector.add(i * _frameNs, base + (random.nextDouble() - 0.5) * 0.06);
      }
      // Intégrale de la fréquence : (20 + 5) / 2 × 4 s = 50 traits.
      expect(detector.marks.length, inInclusiveRange(49, 51));
    });
  });

  test('date les traits précisément malgré les images perdues', () {
    // Comme le CSV de Nathan : un trait toutes les 0,70 s, transitions
    // progressives (~40 ms), bruit, et 4 images perdues toutes les 12.
    const periodS = 0.70;
    final detector = MarkDetector();
    final random = Random(4);
    double luma(double t) {
      final phase = (t % periodS) / periodS;
      // 0.61 → 0.32 en descente linéaire sur 6 % de la période, plateau, remontée.
      if (phase < 0.06) return 0.61 - 0.29 * phase / 0.06;
      if (phase < 0.25) return 0.32;
      if (phase < 0.31) return 0.32 + 0.29 * (phase - 0.25) / 0.06;
      return 0.61;
    }

    for (var i = 0; i < 240 * 20; i++) {
      if (i % 12 >= 8) continue; // images perdues
      final t = i / 240;
      detector.add(i * _frameNs, luma(t) + (random.nextDouble() - 0.5) * 0.01);
    }

    // Le tout premier trait tombe pendant que le seuil se règle : on l'ignore.
    final intervals = detector.recentIntervals(1000).skip(1).toList();
    expect(intervals.length, greaterThan(20));
    for (final interval in intervals) {
      // Datation à l'image près : jusqu'à ±20 ms. Avec l'ajustement du front : < 1 ms.
      expect(interval / 1e6, closeTo(periodS * 1000, 1));
    }
  });

  group('FrameStats', () {
    test('mesure la fréquence et compte les images perdues', () {
      final stats = FrameStats(nominalFps: 240);
      var t = 0;
      for (var i = 0; i < 480; i++) {
        // Un trou de 5 intervalles (4 images perdues) toutes les 100 images.
        t += (i % 100 == 99) ? 5 * _frameNs : _frameNs;
        stats.add(t);
      }
      expect(stats.droppedFrames, 4 * 4);
      expect(stats.maxGapMs, closeTo(20.8, 0.1));
      expect(stats.fps, closeTo(230, 5));
    });
  });
}
