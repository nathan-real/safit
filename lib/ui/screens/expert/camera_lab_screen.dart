import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../services/camera/high_speed_channel.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';
import 'camera_lab_controller.dart';
import 'luma_chart.dart';
import 'roi_overlay.dart';

/// Réglage de la caméra (expérimentateur) : on place la zone de détection,
/// mémorisée pour tous les tests, et on vérifie la mesure.
/// La vidéo est encodée à ~240 fps ; chaque image est décodée et analysée
/// (luminosité de la zone de détection). On peut aussi enregistrer vidéo + CSV.
class CameraLabScreen extends StatefulWidget {
  const CameraLabScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CameraLabScreen()),
    );
  }

  @override
  State<CameraLabScreen> createState() => _CameraLabScreenState();
}

class _CameraLabScreenState extends State<CameraLabScreen> {
  final _lab = CameraLabController(HighSpeedCameraChannel());

  @override
  void initState() {
    super.initState();
    _lab.loadSavedRoi();
  }

  @override
  void dispose() {
    _lab.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (!_lab.isRecording) {
      await _lab.startRecording();
      return;
    }
    final paths = await _lab.stopRecording();
    if (paths.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistré :\n${paths.join('\n')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _lab,
        builder: (context, _) {
          final session = _lab.session;
          return SafitPage(
            header: const SafitHeader(title: 'Réglage caméra', showSettings: false),
            bottom: session == null
                ? SafitButton(
                    label: _lab.starting ? 'Ouverture…' : 'Démarrer la caméra',
                    icon: Icons.videocam_outlined,
                    onPressed: _lab.starting ? null : _lab.start,
                  )
                : SafitButton(
                    label: _lab.stopping ? 'Analyse des dernières images…' : 'Arrêter',
                    icon: Icons.stop_rounded,
                    variant: SafitButtonVariant.danger,
                    onPressed: _lab.stopping ? null : _lab.stop,
                  ),
            children: session == null ? _intro(context) : _running(context, session),
          );
        },
      ),
    );
  }

  List<Widget> _intro(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return [
      Text(
        'La caméra filme en vidéo à 240 images/s. Chaque image de la vidéo est '
        'analysée : on mesure la luminosité du rectangle vert.',
        style: textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      SafitCard(
        child: Text(
          'Placez le rectangle sur les traits noirs et faites tourner le volant. '
          'Si l\'analyse prend du retard, elle le rattrape après l\'arrêt : '
          'aucune image n\'est perdue.',
          style: textTheme.bodySmall,
        ),
      ),
      if (_lab.error != null) ...[
        const SizedBox(height: AppSpacing.lg),
        Text(_lab.error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.danger)),
      ],
      ..._savedFiles(textTheme),
    ];
  }

  List<Widget> _running(BuildContext context, HighSpeedSession session) {
    final textTheme = Theme.of(context).textTheme;
    final stats = _lab.stats;
    final target = session.fps;
    Color? okIf(bool ok) => ok ? AppColors.accent : AppColors.warning;

    return [
      Text(
        session.highSpeed
            ? 'Haute vitesse · ${session.fps} fps · ${session.captureWidth}×${session.captureHeight}'
            : 'Mode normal · ${session.fps} fps (pas de haute vitesse sur ce téléphone)',
        style: textTheme.bodySmall?.copyWith(
          color: session.highSpeed ? AppColors.accent : AppColors.warning,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Center(
        child: SizedBox(
          height: 300,
          child: AspectRatio(
            aspectRatio: session.previewWidth / session.previewHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Texture(textureId: session.textureId),
                  RoiOverlay(roi: _lab.roi, onChanged: _lab.setRoi),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Glissez le rectangle sur les traits ; la poignée ronde le redimensionne.',
        style: textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
      const SectionHeader(title: 'Mesures'),
      _StatsGrid(items: [
        ('Images capteur /s', _lab.sensorFps.toStringAsFixed(0), null),
        ('Images vidéo /s', _lab.videoFps.toStringAsFixed(0), okIf(_lab.videoFps >= target * 0.9)),
        ('Images analysées /s', stats.fps.toStringAsFixed(0), okIf(stats.fps >= target * 0.9)),
        (
          'Retard de l\'analyse',
          '${_lab.analysisLagMs.toStringAsFixed(0)} ms',
          okIf(_lab.analysisLagMs < 500),
        ),
        ('Images perdues', '${stats.droppedFrames}', stats.droppedFrames == 0 ? null : AppColors.warning),
        ('Plus grand trou', '${stats.maxGapMs.toStringAsFixed(1)} ms', null),
        ('Traits détectés', '${_lab.detector.marks.length}', null),
        ('Volant', _fmt(_lab.wheelRpm, 0, 'tr/min'), null),
        ('Intervalle entre traits', _fmt(_lab.meanIntervalMs, 1, 'ms'), null),
        ('Variation (écart-type)', _fmt(_lab.intervalSpreadMs, 1, 'ms'), null),
      ]),
      Text(
        'Moyennes sur les ${CameraLabController.intervalWindow} derniers intervalles. '
        'À vitesse constante, une petite variation = une mesure précise.',
        style: textTheme.bodySmall,
      ),
      const SectionHeader(title: 'Luminosité (2 dernières secondes)'),
      SafitCard(
        child: LumaChart(
          samples: _lab.chart,
          marks: _lab.detector.marks,
          threshold: _lab.detector.threshold,
          windowNs: CameraLabController.chartWindowNs,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Vert : luminosité · pointillés : seuil · repères rouges : traits détectés',
        style: textTheme.bodySmall,
      ),
      const SectionHeader(title: 'Réglages'),
      SafitCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Bloquer l\'exposition'),
              subtitle: Text(
                'Évite que la luminosité change toute seule',
                style: textTheme.bodySmall,
              ),
              value: _lab.exposureLocked,
              onChanged: _lab.setExposureLocked,
            ),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            ListTile(
              title: const Text('Traits sur le volant'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => _lab.setMarkersPerTurn(_lab.markersPerTurn - 1),
                  ),
                  Text('${_lab.markersPerTurn}', style: textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _lab.setMarkersPerTurn(_lab.markersPerTurn + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      SafitButton(
        label: _lab.isRecording
            ? 'Arrêter l\'enregistrement (${_lab.recordedSamples} mesures)'
            : 'Enregistrer vidéo + mesures',
        icon: _lab.isRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
        variant: SafitButtonVariant.secondary,
        onPressed: _lab.stopping ? null : _toggleRecording,
      ),
      ..._savedFiles(textTheme),
      if (session.highSpeedOptions.isNotEmpty) ...[
        const SectionHeader(title: 'Modes haute vitesse du téléphone'),
        Text(session.highSpeedOptions.join('   '), style: textTheme.bodySmall),
      ],
    ];
  }

  static String _fmt(double? value, int decimals, String unit) =>
      value == null ? '--' : '${value.toStringAsFixed(decimals)} $unit';

  List<Widget> _savedFiles(TextTheme textTheme) {
    if (_lab.lastSavedPaths.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Derniers fichiers :\n${_lab.lastSavedPaths.join('\n')}',
        style: textTheme.bodySmall,
      ),
    ];
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});

  final List<(String, String, Color?)> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.2,
      children: [
        for (final (label, value, color) in items)
          SafitCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
