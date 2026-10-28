import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../screens/settings/settings_screen.dart';

/// En-tête de page. Affiche un bouton retour si la route peut être dépilée,
/// et l'accès aux Réglages (désactivable via [showSettings]).
class SafitHeader extends StatelessWidget {
  const SafitHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.showSettings = true,
  }) : assert(title != null || titleWidget != null);

  final String? title;

  /// Remplace [title] (ex. le logo sur l'accueil).
  final Widget? titleWidget;
  final List<Widget> actions;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page - (canPop ? AppSpacing.md : 0),
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (canPop)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            Expanded(
              child: titleWidget ??
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
            ...actions,
            if (showSettings)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Réglages',
                onPressed: () => SettingsScreen.open(context),
              ),
          ],
        ),
      ),
    );
  }
}
