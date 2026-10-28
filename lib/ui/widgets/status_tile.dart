import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'safit_card.dart';

enum StatusLevel {
  ready(AppColors.accent),
  pending(AppColors.warning),
  off(AppColors.textMuted);

  const StatusLevel(this.color);
  final Color color;
}

/// Carte d'état d'un capteur (Polar H10, caméra…) : nom + pastille d'état.
class StatusTile extends StatelessWidget {
  const StatusTile({
    super.key,
    required this.icon,
    required this.label,
    required this.status,
    required this.level,
    this.iconColor = AppColors.accent,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String status;
  final StatusLevel level;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafitCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: level.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  status,
                  style: textTheme.bodySmall?.copyWith(color: level.color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
