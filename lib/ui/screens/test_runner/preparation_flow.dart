import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/test_protocol.dart';
import '../../../services/app_services.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/step_indicator.dart';
import 'preparation_steps.dart';

enum PreparationStep {
  presentation('Présentation'),
  setup('Préparation'),
  camera('Caméra'),
  heartRate('Polar H10'),
  ready('Tout est prêt !');

  const PreparationStep(this.title);
  final String title;
}

/// Parcours guidé avant un test : présentation → préparation → caméra
/// → ceinture → récapitulatif. Le retour (flèche ou bouton Android)
/// revient à l'étape précédente ; la croix permet d'abandonner.
class PreparationFlow extends StatefulWidget {
  const PreparationFlow({super.key, required this.protocol});

  final TestProtocol protocol;

  static Future<void> open(BuildContext context, TestProtocol protocol) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PreparationFlow(protocol: protocol)),
    );
  }

  @override
  State<PreparationFlow> createState() => _PreparationFlowState();
}

class _PreparationFlowState extends State<PreparationFlow> {
  static const _steps = PreparationStep.values;

  int _index = 0;

  PreparationStep get _step => _steps[_index];
  bool get _isLast => _index == _steps.length - 1;

  void _next() {
    if (_isLast) {
      // Lancera l'écran du test en direct.
      showComingSoon(context);
    } else {
      setState(() => _index++);
    }
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index--);
    }
  }

  Future<void> _confirmAbandon() async {
    final abandon = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner le test ?'),
        content: const Text('La préparation en cours sera perdue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer la préparation'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    if (abandon == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final protocol = widget.protocol;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafitPage(
          header: Column(
            children: [
              SafitHeader(
                title: _step.title,
                showSettings: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Abandonner',
                    onPressed: _confirmAbandon,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: StepIndicator(count: _steps.length, current: _index),
              ),
            ],
          ),
          bottom: _ContinueButton(step: _step, protocol: protocol, onPressed: _next),
          children: [
            switch (_step) {
              PreparationStep.presentation => PresentationStep(protocol: protocol),
              PreparationStep.setup => SetupStep(protocol: protocol),
              PreparationStep.camera => const CameraCheckStep(),
              PreparationStep.heartRate => HeartRateStep(protocol: protocol),
              PreparationStep.ready => ReadyStep(protocol: protocol),
            },
          ],
        ),
      ),
    );
  }
}

/// Bouton du bas : désactivé tant que l'étape n'est pas validée
/// (caméra prête, ceinture connectée si le test l'exige).
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.step,
    required this.protocol,
    required this.onPressed,
  });

  final PreparationStep step;
  final TestProtocol protocol;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);

    return switch (step) {
      PreparationStep.camera => ValueListenableBuilder(
          valueListenable: services.camera.state,
          builder: (_, camera, _) => SafitButton(
            label: 'Continuer',
            onPressed: camera.isReady ? onPressed : null,
          ),
        ),
      PreparationStep.heartRate => ValueListenableBuilder(
          valueListenable: services.heartRate.state,
          builder: (_, belt, _) => SafitButton(
            label: belt.isConnected || protocol.requiresHeartRate
                ? 'Continuer'
                : 'Continuer sans ceinture',
            onPressed: belt.isConnected || !protocol.requiresHeartRate ? onPressed : null,
          ),
        ),
      PreparationStep.ready => SafitButton(
          label: 'Commencer le test',
          icon: Icons.play_arrow_rounded,
          onPressed: onPressed,
        ),
      _ => SafitButton(label: 'Continuer', onPressed: onPressed),
    };
  }
}
