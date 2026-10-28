import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'safit_card.dart';

/// Ligne-carte : icône, titre, sous-titre, chevron.
/// Utilisée pour la liste des tests, l'historique, etc.
class SafitListTile extends StatelessWidget {
  const SafitListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.footer,
    this.iconColor = AppColors.accent,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Ligne d'infos sous le sous-titre (durée, date…).
  final Widget? footer;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafitCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: textTheme.bodySmall),
                ],
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DefaultTextStyle.merge(
                    style: textTheme.labelSmall,
                    child: footer!,
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}
