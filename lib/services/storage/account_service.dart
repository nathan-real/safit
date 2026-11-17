import 'package:flutter/foundation.dart';

import '../../models/athlete_profile.dart';

enum AccountStatus {
  /// Lecture du compte en cours (au démarrage).
  loading,

  /// Aucun compte sur ce téléphone : il faut en créer un.
  noAccount,

  /// Un compte existe, il faut saisir le mot de passe.
  loggedOut,
  loggedIn,
}

/// Compte de l'athlète, gardé sur le téléphone (pas de serveur).
/// Implémentations : [MockAccountService] et [LocalAccountService].
abstract interface class AccountService {
  ValueListenable<AccountStatus> get status;

  /// Profil du compte (connu même déconnecté, pour saluer l'athlète).
  ValueListenable<AthleteProfile?> get profile;

  /// Lit le compte enregistré ; à appeler au démarrage.
  Future<void> load();

  /// Crée le compte et connecte l'athlète.
  Future<void> create(AthleteProfile profile, String password);

  /// Vrai si le mot de passe est le bon.
  Future<bool> login(String password);
  Future<void> logout();
  Future<void> updateProfile(AthleteProfile profile);
  void dispose();
}
