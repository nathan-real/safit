import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/test_session.dart';
import '../../widgets/safit_card.dart';

/// Phase de décélération : le sujet ne pédale plus, le volant ralentit seul.
/// Sa pente (vitesse en fonction du temps) donnera la force de friction.
class DecelerationView extends StatelessWidget {
  const DecelerationView(this.session, {super.key});

  final TestSession session;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final curve = session.decelerationCurve;
    final seconds = curve.isEmpty ? 0.0 : curve.last.$1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Arrêtez de pédaler',
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ne touchez plus les pédales : laissez le volant ralentir tout seul.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              session.cadenceRpm?.round().toString() ?? '--',
              style: textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('rpm', style: textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        Text(
          'Phase de décélération · ${seconds.toStringAsFixed(1)} s',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        SafitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vitesse du volant', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.md),
              DecelerationChart(curve: curve),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'La mesure s\'arrête toute seule quand le volant est immobile.',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Fin de la mesure : décélération obtenue et régularité de la pente.
class DecelerationResult extends StatelessWidget {
  const DecelerationResult(this.session, {super.key});

  final TestSession session;

  /// En dessous, la décélération n'est pas assez régulière pour être fiable.
  static const minR2 = 0.95;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final slope = session.decelerationSlope;
    final r2 = session.decelerationR2;
    final reliable = r2 != null && r2 >= minR2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Icon(Icons.check_circle, size: 72, color: AppColors.accent),
        const SizedBox(height: AppSpacing.lg),
        Text('Mesure terminée', style: textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        if (session.decelerationCurve.isNotEmpty)
          SafitCard(
            child: DecelerationChart(curve: session.decelerationCurve, slope: slope, intercept: _intercept()),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ResultTile(
                label: 'Décélération mesurée',
                value: slope == null ? '--' : slope.toStringAsFixed(1),
                unit: 'tr/min par seconde',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ResultTile(
                label: 'Régularité de la pente',
                value: r2 == null ? '--' : '${(r2 * 100).toStringAsFixed(0)} %',
                unit: reliable ? 'décélération linéaire' : 'à refaire',
                color: r2 == null ? null : (reliable ? AppColors.accent : AppColors.warning),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'La décélération donne la force de friction de la courroie, '
          'et donc la puissance : elle sera calculée dans les résultats.',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Ordonnée de la droite ajustée, pour la tracer sur la courbe.
  double? _intercept() {
    final slope = session.decelerationSlope;
    final curve = session.decelerationCurve;
    if (slope == null || curve.isEmpty) return null;
    final meanX = curve.map((p) => p.$1).reduce((a, b) => a + b) / curve.length;
    final meanY = curve.map((p) => p.$2).reduce((a, b) => a + b) / curve.length;
    return meanY - slope * meanX;
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.label, required this.value, required this.unit, this.color});

  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
          Text(unit, style: textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Courbe de la vitesse du volant pendant la décélération, avec en option
/// la droite ajustée (pointillés).
class DecelerationChart extends StatelessWidget {
  const DecelerationChart({super.key, required this.curve, this.slope, this.intercept});

  final List<(double, double)> curve;
  final double? slope;
  final double? intercept;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(painter: _DecelerationPainter(curve, slope, intercept)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 s', style: textTheme.labelSmall),
            Text('temps', style: textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _DecelerationPainter extends CustomPainter {
  _DecelerationPainter(this.curve, this.slope, this.intercept);

  final List<(double, double)> curve;
  final double? slope;
  final double? intercept;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (curve.isEmpty) return;

    // Échelles : au moins 8 s en largeur, de 0 à la vitesse de départ en hauteur.
    final maxT = max(8.0, curve.last.$1);
    final maxV = curve.map((p) => p.$2).reduce(max) * 1.05;
    Offset point(double t, double v) =>
        Offset(t / maxT * size.width, size.height * (1 - (v / maxV).clamp(0.0, 1.0)));

    final path = Path()..moveTo(point(curve.first.$1, curve.first.$2).dx, point(curve.first.$1, curve.first.$2).dy);
    for (final (t, v) in curve.skip(1)) {
      final p = point(t, v);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    final a = slope;
    final b = intercept;
    if (a != null && b != null) {
      final from = point(0, b);
      final to = point(curve.last.$1, a * curve.last.$1 + b);
      final dash = Paint()
        ..color = AppColors.textPrimary
        ..strokeWidth = 1.5;
      const steps = 30;
      for (var i = 0; i < steps; i += 2) {
        canvas.drawLine(
          Offset.lerp(from, to, i / steps)!,
          Offset.lerp(from, to, (i + 1) / steps)!,
          dash,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DecelerationPainter old) =>
      old.curve.length != curve.length || old.slope != slope;
}
