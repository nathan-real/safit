import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Gabarit commun des écrans : header fixe + contenu défilant,
/// centré et limité en largeur sur les grands écrans.
/// [bottom] reste fixé en bas (ex. bouton « Continuer »).
class SafitPage extends StatelessWidget {
  const SafitPage({
    super.key,
    required this.header,
    required this.children,
    this.bottom,
  });

  final Widget header;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: bottom != null,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: Column(
            children: [
              header,
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  children: children,
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
