import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Conteneur de base : fond `surface`, bord fin, coins arrondis.
/// Devient cliquable (avec effet d'encre) si [onTap] est fourni.
class SafitCard extends StatelessWidget {
  const SafitCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
