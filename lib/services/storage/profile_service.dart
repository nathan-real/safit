import 'package:flutter/foundation.dart';

import '../../models/athlete_profile.dart';

/// Profil de l'athlète.
/// Implémentations : [MockProfileService], puis un stockage local réel.
abstract interface class ProfileService {
  /// Profil courant, ou null s'il n'a pas encore été renseigné.
  ValueListenable<AthleteProfile?> get profile;

  Future<void> save(AthleteProfile profile);
  void dispose();
}
