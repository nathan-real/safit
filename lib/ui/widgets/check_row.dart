import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum CheckState { ok, pending, missing }

/// Ligne de vérification : ✓ / … / ✗ + libellé + détail à droite.
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.label,
    required this.state,
    this.detail,
  });

  final String label;
  final CheckState state;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, color) = switch (state) {
      CheckState.ok => (Icons.check_circle, AppColors.accent),
      CheckState.pending => (Icons.hourglass_top_rounded, AppColors.warning),
      CheckState.missing => (Icons.cancel_outlined, AppColors.textMuted),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: textTheme.bodyLarge)),
          if (detail != null)
            Text(detail!, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
