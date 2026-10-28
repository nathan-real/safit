import 'package:flutter/material.dart';

/// Retour temporaire pour les entrées pas encore implémentées.
void showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Bientôt disponible')));
}
