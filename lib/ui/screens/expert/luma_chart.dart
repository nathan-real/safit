import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Courbe de luminosité des dernières secondes, avec le seuil de détection
/// (pointillés) et un repère rouge en haut à chaque trait détecté.
class LumaChart extends StatelessWidget {
  const LumaChart({
    super.key,
    required this.samples,
    required this.marks,
    required this.threshold,
    required this.windowNs,
  });

  final ListQueue<(int, double)> samples;
  final List<int> marks;
  final double? threshold;
  final int windowNs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: CustomPaint(
        painter: _LumaPainter(samples, marks, threshold, windowNs),
      ),
    );
  }
}

class _LumaPainter extends CustomPainter {
  _LumaPainter(this.samples, this.marks, this.threshold, this.windowNs);

  final ListQueue<(int, double)> samples;
  final List<int> marks;
  final double? threshold;
  final int windowNs;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (samples.length < 2) return;

    // Échelle verticale ajustée au signal, pour bien voir les creux.
    var min = 1.0;
    var max = 0.0;
    for (final (_, v) in samples) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final pad = (max - min) * 0.1 + 0.01;
    min -= pad;
    max += pad;

    final end = samples.last.$1;
    final start = end - windowNs;
    double x(int t) => (t - start) / windowNs * size.width;
    double y(double v) => size.height * (1 - (v - min) / (max - min));

    final path = Path();
    var first = true;
    for (final (t, v) in samples) {
      if (first) {
        path.moveTo(x(t), y(v));
        first = false;
      } else {
        path.lineTo(x(t), y(v));
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    final th = threshold;
    if (th != null) {
      final ty = y(th);
      final dash = Paint()
        ..color = AppColors.warning
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, ty), Offset(dx + 4, ty), dash);
      }
    }

    final tick = Paint()
      ..color = AppColors.heartRate
      ..strokeWidth = 2;
    for (var i = marks.length - 1; i >= 0 && marks[i] >= start; i--) {
      final mx = x(marks[i]);
      canvas.drawLine(Offset(mx, 0), Offset(mx, 10), tick);
    }
  }

  // Les données changent en place : on redessine à chaque reconstruction.
  @override
  bool shouldRepaint(_LumaPainter oldDelegate) => true;
}
