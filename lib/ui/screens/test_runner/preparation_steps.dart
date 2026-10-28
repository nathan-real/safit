import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/camera_state.dart';
import '../../../models/test_protocol.dart';
import '../../../services/app_services.dart';
import '../../widgets/check_row.dart';
import '../../widgets/heart_rate_panel.dart';
import '../../widgets/numbered_steps.dart';
import '../../widgets/protocol_icon.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/section_header.dart';
import '../settings/settings_screen.dart';

// Contenu des étapes du parcours de préparation (voir PreparationFlow).

/// 1. Ce que fait le test et comment il se déroule.
class PresentationStep extends StatelessWidget {
  const PresentationStep({super.key, required this.protocol});

  final TestProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(protocol.icon, size: 40, color: AppColors.accent),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: Text(protocol.title, style: textTheme.headlineSmall)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(protocol.description, style: textTheme.bodyMedium),
        const SectionHeader(title: 'Objectif'),
        SizedBox(
          width: double.infinity,
          child: SafitCard(child: Text(protocol.objective, style: textTheme.bodyMedium)),
        ),
        const SectionHeader(title: 'Déroulement'),
        SafitCard(child: NumberedSteps(steps: protocol.procedure)),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text('Durée : ${protocol.duration}', style: textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

/// 2. Installation du téléphone et de la ceinture.
class SetupStep extends StatelessWidget {
  const SetupStep({super.key, required this.protocol});

  final TestProtocol protocol;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Avant de commencer, installez le matériel.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        SafitCard(
          child: NumberedSteps(steps: [
            'Posez le téléphone à plat sur son support, au-dessus du volant, '
                'caméra tournée vers les traits noirs.',
            'Humidifiez les électrodes de la ceinture Polar et placez-la '
                'sous les pectoraux.',
            if (protocol != TestProtocol.frictionCalibration)
              'Réglez la tension de la courroie : l\'effort doit rester confortable.',
            'Installez-vous sur le vélo, l\'écran du téléphone à portée de main.',
          ]),
        ),
      ],
    );
  }
}

/// 3. Vérification rapide de la caméra (la zone de détection est réglée
/// une fois pour toutes en mode expert).
class CameraCheckStep extends StatelessWidget {
  const CameraCheckStep({super.key});

  @override
  Widget build(BuildContext context) {
    final camera = AppServices.of(context).camera;

    return ValueListenableBuilder(
      valueListenable: camera.state,
      builder: (context, state, _) {
        final checking = state.status == CameraStatus.checking;
        CheckState check(bool ok) =>
            checking ? CheckState.pending : (ok ? CheckState.ok : CheckState.missing);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Faites tourner le volant à la main : la caméra doit voir passer les traits.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SafitCard(
              child: Column(
                children: [
                  CheckRow(
                    label: 'Caméra',
                    state: check(state.isReady),
                    detail: state.fps == null ? null : '${state.fps!.round()} fps',
                  ),
                  CheckRow(
                    label: 'Marqueurs détectés',
                    state: check((state.markersDetected ?? 0) > 0),
                    detail: state.markersDetected?.toString(),
                  ),
                  CheckRow(
                    label: 'Signal',
                    state: check(state.signalStable),
                    detail: state.signalStable ? 'Stable' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SafitButton(
              label: checking ? 'Vérification…' : 'Tester la détection',
              icon: Icons.center_focus_strong_outlined,
              variant: SafitButtonVariant.secondary,
              onPressed: checking ? null : camera.runDetectionCheck,
            ),
            if (state.status == CameraStatus.notConfigured) ...[
              const SizedBox(height: AppSpacing.lg),
              _Notice(
                text: 'La zone de détection n\'est pas encore réglée. '
                    'Demandez à l\'expérimentateur de la régler dans le mode expert.',
                actionLabel: 'Ouvrir les réglages',
                onAction: () => SettingsScreen.open(context),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 4. Connexion de la ceinture cardiaque.
class HeartRateStep extends StatelessWidget {
  const HeartRateStep({super.key, required this.protocol});

  final TestProtocol protocol;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!protocol.requiresHeartRate) ...[
          const _Notice(
            text: 'Facultatif pour ce test : vous pouvez continuer sans ceinture.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        const HeartRatePanel(),
      ],
    );
  }
}

/// 5. Récapitulatif avant de lancer.
class ReadyStep extends StatelessWidget {
  const ReadyStep({super.key, required this.protocol});

  final TestProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafitCard(
          child: Column(
            children: [
              CheckRow(label: protocol.title, state: CheckState.ok, detail: protocol.duration),
              ValueListenableBuilder(
                valueListenable: services.camera.state,
                builder: (_, camera, _) => CheckRow(
                  label: 'Caméra',
                  state: camera.isReady ? CheckState.ok : CheckState.missing,
                  detail: camera.isReady
                      ? '${camera.fps?.round()} fps · ${camera.markersDetected} marqueurs'
                      : 'Non prête',
                ),
              ),
              ValueListenableBuilder(
                valueListenable: services.heartRate.state,
                builder: (_, belt, _) => CheckRow(
                  label: 'Polar H10',
                  state: belt.isConnected ? CheckState.ok : CheckState.missing,
                  detail: belt.isConnected ? '${belt.bpm} bpm' : 'Non connectée',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Notice(
          text: 'La mesure démarrera d\'elle-même dès vos premiers coups de pédale.',
        ),
      ],
    );
  }
}

/// Encadré d'information, avec une action optionnelle.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SafitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
          if (actionLabel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
        ],
      ),
    );
  }
}
