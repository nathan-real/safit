import 'package:flutter/material.dart';

/// Palette SAFiT. L'application n'a qu'un thème sombre : elle est utilisée
/// en salle, téléphone posé sur l'ergocycle, et doit rester lisible d'un coup d'œil.
abstract final class AppColors {
  // Fonds
  static const background = Color(0xFF0B0D0F);
  static const surface = Color(0xFF15181B);
  static const surfaceRaised = Color(0xFF1E2226);
  static const border = Color(0xFF2A2F35);

  // Accent de marque (vert citron)
  static const accent = Color(0xFFD4F53C);
  static const onAccent = Color(0xFF0B0D0F);

  // Texte
  static const textPrimary = Color(0xFFF5F7F8);
  static const textSecondary = Color(0xFF9BA3AB);
  static const textMuted = Color(0xFF5F676F);

  // Sémantique
  static const danger = Color(0xFFFF4B4B);
  static const warning = Color(0xFFFFB547);
  static const info = Color(0xFF4DA3FF);

  // Grandeurs mesurées : une couleur fixe par signal, partout dans l'app
  static const heartRate = Color(0xFFFF4D5E);
  static const power = accent;
  static const cadence = info;
}
