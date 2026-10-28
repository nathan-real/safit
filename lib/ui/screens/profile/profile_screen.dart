import 'package:flutter/material.dart';

import '../../widgets/coming_soon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafitPage(
      header: const SafitHeader(title: 'Mon profil'),
      children: [
        EmptyState(
          icon: Icons.person_outline,
          title: 'Profil non renseigné',
          message: 'Âge, poids et taille permettent d\'interpréter vos tests.',
          action: SafitButton(
            label: 'Compléter mon profil',
            variant: SafitButtonVariant.secondary,
            expanded: false,
            onPressed: () => showComingSoon(context),
          ),
        ),
      ],
    );
  }
}
