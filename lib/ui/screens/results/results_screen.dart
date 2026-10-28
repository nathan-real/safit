import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafitPage(
      header: SafitHeader(title: 'Résultats'),
      children: [
        EmptyState(
          icon: Icons.insights_outlined,
          title: 'Aucun résultat',
          message: 'Les résultats de vos tests seront enregistrés ici.',
        ),
      ],
    );
  }
}
