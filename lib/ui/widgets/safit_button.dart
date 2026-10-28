import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum SafitButtonVariant { primary, secondary, danger }

/// Bouton principal de l'app. Pleine largeur par défaut : sur le vélo,
/// les cibles doivent être grandes.
class SafitButton extends StatelessWidget {
  const SafitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = SafitButtonVariant.primary,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SafitButtonVariant variant;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final iconWidget = icon == null ? null : Icon(icon);
    final labelWidget = Text(label);

    final button = switch (variant) {
      SafitButtonVariant.primary => FilledButton.icon(
          onPressed: onPressed,
          icon: iconWidget,
          label: labelWidget,
        ),
      SafitButtonVariant.secondary => OutlinedButton.icon(
          onPressed: onPressed,
          icon: iconWidget,
          label: labelWidget,
        ),
      SafitButtonVariant.danger => FilledButton.icon(
          onPressed: onPressed,
          icon: iconWidget,
          label: labelWidget,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
