import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/test_protocol.dart';
import '../../widgets/numbered_steps.dart';
import '../../widgets/protocol_icon.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';

/// Fiches pratiques : installer le téléphone, puis le déroulé de chaque test.
class TutorialsScreen extends StatelessWidget {
  const TutorialsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TutorialsScreen()),
    );
  }

  static const _setup = [
    'Tracez des traits noirs réguliers sur le bord blanc du volant.',
    'Posez le téléphone sur son support, caméra face au volant, à 10–20 cm.',
    'Éclairez bien le volant : plus il y a de lumière, plus la mesure est nette.',
    'Mode expert › Réglage caméra : placez la zone de détection sur les traits.',
    'Mettez la ceinture Polar H10 (électrodes humidifiées) et connectez-la.',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafitPage(
        header: const SafitHeader(title: 'Tutoriels', showSettings: false),
        children: [
          const SectionHeader(title: 'Installer le matériel'),
          const SafitCard(child: NumberedSteps(steps: _setup)),
          const SectionHeader(title: 'Les tests'),
          for (final p in TestProtocol.values) ...[
            SafitCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                leading: Icon(p.icon, color: AppColors.accent),
                title: Text(p.title),
                subtitle: Text(p.duration, style: textTheme.bodySmall),
                shape: const Border(),
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.objective, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.lg),
                  NumberedSteps(steps: p.procedure),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
