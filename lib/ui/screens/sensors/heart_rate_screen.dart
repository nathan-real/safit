import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../widgets/heart_rate_panel.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';

/// Écran de la ceinture cardiaque : connexion, FC en direct, batterie.
class HeartRateScreen extends StatelessWidget {
  const HeartRateScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HeartRateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafitPage(
        header: const SafitHeader(title: 'Polar H10', showSettings: false),
        children: [
          const HeartRatePanel(allowDisconnect: true),
          const SectionHeader(title: 'Bien porter la ceinture'),
          SafitCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Humidifiez les électrodes et serrez la ceinture juste sous '
                    'les pectoraux. Le module Polar doit être bien clipsé.',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
