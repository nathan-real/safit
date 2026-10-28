import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_list_tile.dart';
import '../../widgets/safit_page.dart';

typedef _TestEntry = ({
  IconData icon,
  String title,
  String description,
  String duration,
});

// Protocoles tels que décrits par le Pr Arsac.
const List<_TestEntry> _tests = [
  (
    icon: Icons.bar_chart_rounded,
    title: 'Test sous-maximal',
    description:
        '2 paliers à charge différente, avec repos entre les deux. '
        'Donne la pente fréquence cardiaque / puissance.',
    duration: '2 × 5 min',
  ),
  (
    icon: Icons.trending_up_rounded,
    title: 'Test incrémental',
    description:
        'Paliers de cadence de 40 à 80 rpm, environ 1 min chacun. '
        'Un bip signale chaque changement.',
    duration: '≈ 7 min + 2 min récup.',
  ),
  (
    icon: Icons.bolt_rounded,
    title: 'Test force-vitesse',
    description:
        'Sprint départ arrêté, effort maximal. '
        'La mesure démarre au premier coup de pédale.',
    duration: '6 – 8 s',
  ),
  (
    icon: Icons.settings_suggest_outlined,
    title: 'Calibration friction',
    description:
        'Lancez le volant puis arrêtez de pédaler : '
        'la décélération donne la force de friction.',
    duration: '< 1 min',
  ),
];

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafitPage(
      header: const SafitHeader(title: 'Choisir un test'),
      children: [
        for (final test in _tests) ...[
          SafitListTile(
            icon: test.icon,
            title: test.title,
            subtitle: test.description,
            footer: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Text(test.duration),
              ],
            ),
            onTap: () => showComingSoon(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
