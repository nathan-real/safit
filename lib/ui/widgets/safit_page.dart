import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Gabarit commun des écrans : header fixe + contenu défilant,
/// centré et limité en largeur sur les grands écrans.
class SafitPage extends StatelessWidget {
  const SafitPage({super.key, required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
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
            ],
          ),
        ),
      ),
    );
  }
}
