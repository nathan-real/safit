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

/// Écran de test de la caméra haute fréquence (mode expert).
/// Sert à vérifier sur un vrai téléphone qu'on analyse bien ~240 images/s
/// en direct, et à enregistrer les mesures pour les étudier sur ordinateur.
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
  void dispose() {
    _lab.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (!_lab.isRecording) {
      _lab.startRecording();
      return;
    }
    final path = await _lab.stopRecording();
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesures enregistrées :\n$path')),
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
            header: const SafitHeader(title: 'Prototype caméra', showSettings: false),
            bottom: session == null
                ? SafitButton(
                    label: _lab.starting ? 'Ouverture…' : 'Démarrer la caméra',
                    icon: Icons.videocam_outlined,
                    onPressed: _lab.starting ? null : _lab.start,
                  )
                : SafitButton(
                    label: 'Arrêter',
                    icon: Icons.stop_rounded,
                    variant: SafitButtonVariant.danger,
                    onPressed: _lab.stop,
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
        'Cet écran vérifie que le téléphone peut analyser la caméra en direct, '
        'sans enregistrer de vidéo.',
        style: textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      SafitCard(
        child: Text(
          'À chaque image, l\'app mesure la luminosité du rectangle vert, '
          'puis jette l\'image. Placez le rectangle sur les traits noirs '
          'et faites tourner le volant.',
          style: textTheme.bodySmall,
        ),
      ),
      if (_lab.error != null) ...[
        const SizedBox(height: AppSpacing.lg),
        Text(_lab.error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.danger)),
      ],
      if (_lab.lastSavedPath != null) ...[
        const SizedBox(height: AppSpacing.lg),
        Text('Dernier fichier : ${_lab.lastSavedPath}', style: textTheme.bodySmall),
      ],
    ];
  }

  List<Widget> _running(BuildContext context, HighSpeedSession session) {
    final textTheme = Theme.of(context).textTheme;
    final stats = _lab.stats;
    final fpsOk = stats.fps >= session.fps * 0.95;
    // Budget de temps par image pour tenir la fréquence demandée (4,2 ms à 240 fps).
    final budgetMs = 1000 / session.fps;
    final workMs = _lab.workMs;

    return [
      Text(
        session.highSpeed
            ? 'Haute vitesse · ${session.fps} fps · ${session.captureWidth}×${session.captureHeight}'
            : 'Mode normal · ${session.fps} fps (pas de haute vitesse sur ce téléphone)',
        style: textTheme.bodySmall?.copyWith(
          color: session.highSpeed ? AppColors.accent : AppColors.warning,
        ),
      ),
      Text(
        session.asyncReadback
            ? 'Lecture du calcul sans attente (OpenGL ES 3)'
            : 'Lecture du calcul avec attente (OpenGL ES 2)',
        style: textTheme.bodySmall,
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
        ('Images analysées /s', stats.fps.toStringAsFixed(0), fpsOk ? AppColors.accent : AppColors.warning),
        ('Images capteur /s', _lab.sensorFps.toStringAsFixed(0), null),
        ('Images perdues', '${stats.droppedFrames}', stats.droppedFrames == 0 ? null : AppColors.warning),
        ('Plus grand trou', '${stats.maxGapMs.toStringAsFixed(1)} ms', null),
        (
          'Calcul / image',
          workMs == null ? '--' : '${workMs.toStringAsFixed(2)} ms',
          workMs == null ? null : (workMs < budgetMs ? AppColors.accent : AppColors.warning),
        ),
        ('Budget / image', '${budgetMs.toStringAsFixed(2)} ms', null),
        ('Traits détectés', '${_lab.detector.marks.length}', null),
        ('Volant', '${_lab.wheelRpm.toStringAsFixed(0)} tr/min', null),
      ]),
      const SectionHeader(title: 'Diagnostic'),
      Text(
        'Coupez l\'un puis l\'autre et notez « Images analysées /s » à chaque fois.',
        style: textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      SafitCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Aperçu'),
              subtitle: Text('Affichage de l\'image à l\'écran', style: textTheme.bodySmall),
              value: _lab.previewEnabled,
              onChanged: _lab.setPreviewEnabled,
            ),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            SwitchListTile(
              title: const Text('Analyse'),
              subtitle: Text(
                'Mesure de la luminosité (coupée : on ne garde que l\'heure des images)',
                style: textTheme.bodySmall,
              ),
              value: _lab.analysisEnabled,
              onChanged: _lab.setAnalysisEnabled,
            ),
          ],
        ),
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
            : 'Enregistrer les mesures (CSV)',
        icon: _lab.isRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
        variant: SafitButtonVariant.secondary,
        onPressed: _toggleRecording,
      ),
      if (_lab.lastSavedPath != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text('Dernier fichier : ${_lab.lastSavedPath}', style: textTheme.bodySmall),
      ],
      if (session.highSpeedOptions.isNotEmpty) ...[
        const SectionHeader(title: 'Modes haute vitesse du téléphone'),
        Text(session.highSpeedOptions.join('   '), style: textTheme.bodySmall),
      ],
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
