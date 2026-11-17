import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/camera_state.dart';
import '../../../services/app_services.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';
import '../settings/ergocycle_screen.dart';
import 'camera_lab_screen.dart';

/// Outils de l'expérimentateur : réglage de la caméra, paramètres de
/// l'ergocycle et diagnostic de la détection.
class ExpertScreen extends StatelessWidget {
  const ExpertScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ExpertScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafitPage(
        header: const SafitHeader(title: 'Mode expert', showSettings: false),
        children: [
          Text(
            'Réglages réservés à l\'expérimentateur. Ils s\'appliquent à tous les tests.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SectionHeader(title: 'Réglages'),
          SafitCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
                  title: const Text('Réglage caméra'),
                  subtitle: Text('Zone de détection, aperçu 240 i/s, enregistrement',
                      style: textTheme.bodySmall),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => CameraLabScreen.open(context),
                ),
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                ValueListenableBuilder(
                  valueListenable: services.ergocycle.parameters,
                  builder: (_, p, _) => ListTile(
                    leading: const Icon(Icons.pedal_bike_outlined, color: AppColors.accent),
                    title: const Text('Paramètres de l\'ergocycle'),
                    subtitle: Text(
                      p.provisional ? 'Valeurs provisoires' : 'Valeurs enregistrées',
                      style: textTheme.bodySmall?.copyWith(
                        color: p.provisional ? AppColors.warning : null,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () => ErgocycleScreen.open(context),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Diagnostic caméra'),
          ValueListenableBuilder(
            valueListenable: services.camera.state,
            builder: (_, state, _) => _Diagnostic(state),
          ),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder(
            valueListenable: services.camera.state,
            builder: (_, state, _) => SafitButton(
              label: state.status == CameraStatus.checking
                  ? 'Vérification…'
                  : 'Vérifier la détection (3 s)',
              icon: Icons.play_circle_outline,
              variant: SafitButtonVariant.secondary,
              onPressed: state.status == CameraStatus.checking
                  ? null
                  : services.camera.runDetectionCheck,
            ),
          ),
        ],
      ),
    );
  }
}

class _Diagnostic extends StatelessWidget {
  const _Diagnostic(this.state);

  final CameraState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final realTest = state.highSpeed && state.status == CameraStatus.ready;
    final rows = [
      ('État', switch (state.status) {
        CameraStatus.ready => 'Prête',
        CameraStatus.checking => 'Vérification…',
        CameraStatus.notConfigured => 'Zone de détection non réglée',
        CameraStatus.error => 'Indisponible',
      }),
      ('Images / s', state.fps == null ? '--' : state.fps!.round().toString()),
      ('Mode haute vitesse', state.highSpeed ? 'Oui' : 'Non'),
      ('Traits vus', state.markersDetected?.toString() ?? '--'),
      ('Tests', realTest ? 'Mesurés par la caméra' : 'Simulés'),
    ];
    return SafitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  ),
                  Text(value, style: textTheme.bodyMedium),
                ],
              ),
            ),
          if (state.message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(state.message!, style: textTheme.bodySmall?.copyWith(color: AppColors.warning)),
          ],
        ],
      ),
    );
  }
}
