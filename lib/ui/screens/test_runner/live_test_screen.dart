import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/test_protocol.dart';
import '../../../models/test_session.dart';
import '../../../services/app_services.dart';
import '../../../services/test/test_data_service.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';

/// Écran du test en direct : attente des premiers coups de pédale, puis
/// cadence, fréquence cardiaque et chrono, avec un affichage propre à chaque
/// protocole. Pas de puissance ici : elle n'est connue qu'après la décélération.
class LiveTestScreen extends StatefulWidget {
  const LiveTestScreen({super.key, required this.protocol});

  final TestProtocol protocol;

  /// Remplace l'écran courant (le parcours de préparation) : le retour mène
  /// ensuite directement au choix du test.
  static Future<void> replace(BuildContext context, TestProtocol protocol) {
    return Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => LiveTestScreen(protocol: protocol)),
    );
  }

  @override
  State<LiveTestScreen> createState() => _LiveTestScreenState();
}

class _LiveTestScreenState extends State<LiveTestScreen> {
  late TestDataService _test;
  int? _lastStage;
  TestPhase? _lastPhase;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _test = AppServices.of(context).testData;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _test.session.addListener(_signalChanges);
      _test.arm(widget.protocol);
    });
  }

  @override
  void dispose() {
    _test.session.removeListener(_signalChanges);
    if (_test.session.value?.isActive ?? false) _test.abort();
    _test.reset();
    super.dispose();
  }

  /// Bip + vibration à chaque nouveau palier, et quand il faut arrêter de pédaler.
  void _signalChanges() {
    final s = _test.session.value;
    if (s == null) return;
    final newStage = s.phase == TestPhase.running && s.stageIndex != null &&
        _lastStage != null && s.stageIndex != _lastStage;
    final stopSignal = s.phase == TestPhase.deceleration && _lastPhase == TestPhase.running;
    if (newStage || stopSignal) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
    _lastStage = s.stageIndex;
    _lastPhase = s.phase;
  }

  Future<void> _confirmStop() async {
    final s = _test.session.value;
    if (s == null || !s.isActive) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final armed = s.phase == TestPhase.armed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(armed ? 'Annuler le test ?' : 'Arrêter le test ?'),
        content: Text(
          armed
              ? 'La mesure n\'a pas encore commencé.'
              : 'Arrêtez de pédaler ensuite : le volant doit ralentir seul.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer le test'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(armed ? 'Annuler' : 'Arrêter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (armed) {
      await _test.abort();
      if (mounted) Navigator.of(context).pop();
    } else {
      await _test.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop();
      },
      child: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: _test.session,
          builder: (context, session, _) {
            final phase = session?.phase ?? TestPhase.armed;
            return SafitPage(
              header: SafitHeader(title: widget.protocol.title, showSettings: false),
              bottom: switch (phase) {
                TestPhase.armed => SafitButton(
                    label: 'Annuler',
                    variant: SafitButtonVariant.secondary,
                    onPressed: _confirmStop,
                  ),
                TestPhase.running => SafitButton(
                    label: 'Arrêter',
                    icon: Icons.stop_rounded,
                    variant: SafitButtonVariant.danger,
                    onPressed: _confirmStop,
                  ),
                TestPhase.deceleration => null,
                TestPhase.finished || TestPhase.aborted => SafitButton(
                    label: 'Terminer',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              },
              children: [
                switch (phase) {
                  TestPhase.armed => const _ArmedView(),
                  TestPhase.running => _RunningView(session!),
                  TestPhase.deceleration => _DecelerationView(session!),
                  TestPhase.finished || TestPhase.aborted => const _FinishedView(),
                },
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Avant le départ : la mesure se lancera seule aux premiers traits détectés.
class _ArmedView extends StatelessWidget {
  const _ArmedView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl * 2),
      child: Column(
        children: [
          const Icon(Icons.pedal_bike, size: 96, color: AppColors.accent),
          const SizedBox(height: AppSpacing.xl),
          Text('Commencez à pédaler', style: textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(
            'La mesure démarre toute seule dès les premiers coups de pédale.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    );
  }
}

class _RunningView extends StatelessWidget {
  const _RunningView(this.session);

  final TestSession session;

  /// Écart toléré autour de la cadence cible (rpm).
  static const cadenceTolerance = 3.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final protocol = session.protocol;
    final target = session.targetCadenceRpm;
    final cadence = session.cadenceRpm;
    final offTarget = target != null && cadence != null && (cadence - target).abs() > cadenceTolerance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            formatDuration(session.elapsed),
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (protocol == TestProtocol.forceVelocity)
          const _Banner('Sprintez !', color: AppColors.accent),
        if (protocol == TestProtocol.frictionCalibration)
          const _Banner('Lancez le volant, puis arrêtez de pédaler'),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: _CadenceGauge(
            cadence: cadence,
            target: target,
            color: offTarget ? AppColors.warning : AppColors.accent,
          ),
        ),
        if (target != null) ...[
          const SizedBox(height: AppSpacing.md),
          Center(child: _CadenceAdvice(cadence: cadence, target: target)),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _Metric(
                icon: Icons.favorite,
                iconColor: AppColors.heartRate,
                label: 'Fréquence cardiaque',
                value: session.heartRateBpm?.toString() ?? '--',
                unit: 'bpm',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _protocolMetric()),
          ],
        ),
      ],
    );
  }

  /// Seconde carte, selon le protocole.
  Widget _protocolMetric() {
    switch (session.protocol) {
      case TestProtocol.incremental:
        final stage = (session.stageIndex ?? 0) + 1;
        return _Metric(
          icon: Icons.stairs_outlined,
          label: 'Palier $stage/${session.stageCount ?? '-'}',
          value: session.stageRemaining == null ? '--' : formatDuration(session.stageRemaining!),
          unit: 'avant le suivant',
        );
      case TestProtocol.subMaximal:
      case TestProtocol.frictionCalibration:
        return _Metric(
          icon: Icons.timer_outlined,
          label: 'Temps restant',
          value: session.remaining == null ? '--' : formatDuration(session.remaining!),
          unit: '',
        );
      case TestProtocol.forceVelocity:
        return _Metric(
          icon: Icons.bolt,
          label: 'Durée du sprint',
          value: (session.elapsed.inMilliseconds / 1000).toStringAsFixed(1),
          unit: 's',
        );
    }
  }
}

/// « Bonne cadence » / « Trop vite » / « Trop lent » par rapport à la cible.
class _CadenceAdvice extends StatelessWidget {
  const _CadenceAdvice({required this.cadence, required this.target});

  final double? cadence;
  final double target;

  @override
  Widget build(BuildContext context) {
    final c = cadence;
    final (text, color) = switch (c) {
      null => ('En attente', AppColors.textSecondary),
      _ when c > target + _RunningView.cadenceTolerance => ('Trop vite : ralentissez', AppColors.warning),
      _ when c < target - _RunningView.cadenceTolerance => ('Trop lent : accélérez', AppColors.warning),
      _ => ('Bonne cadence', AppColors.accent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

/// Grand cercle : cadence au centre, arc proportionnel à la cadence,
/// et repère blanc sur la cadence cible (test incrémental).
class _CadenceGauge extends StatelessWidget {
  const _CadenceGauge({required this.cadence, required this.target, required this.color});

  final double? cadence;
  final double? target;
  final Color color;

  /// Cadence correspondant à l'arc plein.
  static const maxRpm = 140.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 240,
      height: 240,
      child: CustomPaint(
        painter: _GaugePainter(
          fraction: ((cadence ?? 0) / maxRpm).clamp(0.0, 1.0),
          targetFraction: target == null ? null : (target! / maxRpm).clamp(0.0, 1.0),
          color: color,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cadence == null ? '--' : cadence!.round().toString(),
                style: textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('rpm', style: textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
              if (target != null)
                Text(
                  'Cible ${target!.round()} rpm',
                  style: textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction, required this.targetFraction, required this.color});

  final double fraction;
  final double? targetFraction;
  final Color color;

  // Arc de 270°, ouvert en bas.
  static const _start = 0.75 * pi;
  static const _sweep = 1.5 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke);
    final base = Paint()
      ..color = AppColors.surfaceRaised
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, _start, _sweep, false, base);
    canvas.drawArc(arcRect, _start, _sweep * fraction, false, base..color = color);

    final t = targetFraction;
    if (t != null) {
      final angle = _start + _sweep * t;
      final center = rect.center;
      final radius = arcRect.width / 2;
      final inner = center + Offset(cos(angle), sin(angle)) * (radius - stroke);
      final outer = center + Offset(cos(angle), sin(angle)) * (radius + stroke);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = AppColors.textPrimary
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.targetFraction != targetFraction || old.color != color;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.iconColor = AppColors.accent,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(label, style: textTheme.bodySmall, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (unit.isNotEmpty) Text(unit, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {this.color = AppColors.textPrimary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
    );
  }
}

/// Provisoire : l'écran dédié à la décélération fera l'objet du ticket suivant.
class _DecelerationView extends StatelessWidget {
  const _DecelerationView(this.session);

  final TestSession session;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        children: [
          Text('Arrêtez de pédaler', style: textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Laissez le volant ralentir tout seul.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            session.cadenceRpm?.round().toString() ?? '--',
            style: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text('rpm', style: textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Provisoire : l'écran des résultats fera l'objet d'un ticket suivant.
class _FinishedView extends StatelessWidget {
  const _FinishedView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl * 2),
      child: Column(
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.accent),
          const SizedBox(height: AppSpacing.lg),
          Text('Mesure terminée', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Les résultats s\'afficheront ici.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
