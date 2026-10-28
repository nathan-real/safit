import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shell/app_shell.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_logo.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shell = AppShell.of(context);

    return SafitPage(
      header: const SafitHeader(titleWidget: SafitLogo()),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('Bonjour 👋', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Prêt pour un nouveau test ?',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        SafitButton(
          label: 'Nouveau test',
          icon: Icons.play_arrow_rounded,
          onPressed: () => shell.goTo(AppTab.tests),
        ),
        const SectionHeader(title: 'État du système'),
        // États figés : seront branchés aux services BLE / caméra.
        const Row(
          children: [
            Expanded(
              child: StatusTile(
                icon: Icons.favorite_border,
                iconColor: AppColors.heartRate,
                label: 'Polar H10',
                status: 'Non connectée',
                level: StatusLevel.off,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatusTile(
                icon: Icons.photo_camera_outlined,
                label: 'Caméra',
                status: 'Non configurée',
                level: StatusLevel.off,
              ),
            ),
          ],
        ),
        SectionHeader(
          title: 'Tests récents',
          actionLabel: 'Voir tout',
          onAction: () => shell.goTo(AppTab.results),
        ),
        const EmptyState(
          icon: Icons.history,
          title: 'Aucun test pour l\'instant',
          message: 'Vos derniers tests apparaîtront ici.',
        ),
      ],
    );
  }
}
