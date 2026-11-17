import 'package:flutter/foundation.dart';

import '../../models/athlete_profile.dart';
import 'account_service.dart';

/// Compte fictif en mémoire (tests automatisés, démonstration).
/// Mot de passe : « safit ».
class MockAccountService implements AccountService {
  /// [initial] : connecté (par défaut), déconnecté, ou sans compte
  /// (premier lancement : écran de création du profil).
  MockAccountService({AccountStatus initial = AccountStatus.loggedIn}) {
    if (initial != AccountStatus.noAccount) _profile.value = _sample;
    _status.value = initial;
  }

  static const password = 'safit';

  static const _sample = AthleteProfile(
    firstName: 'Léa',
    lastName: 'Martin',
    age: 24,
    weightKg: 65,
    heightCm: 170,
    sport: 'Cyclisme',
    goal: 'Améliorer l\'endurance',
  );

  final _status = ValueNotifier(AccountStatus.loading);
  final _profile = ValueNotifier<AthleteProfile?>(null);
  String _password = password;

  @override
  ValueListenable<AccountStatus> get status => _status;

  @override
  ValueListenable<AthleteProfile?> get profile => _profile;

  @override
  Future<void> load() async {}

  @override
  Future<void> create(AthleteProfile profile, String password) async {
    _profile.value = profile;
    _password = password;
    _status.value = AccountStatus.loggedIn;
  }

  @override
  Future<bool> login(String password) async {
    if (password != _password) return false;
    _status.value = AccountStatus.loggedIn;
    return true;
  }

  @override
  Future<void> logout() async => _status.value = AccountStatus.loggedOut;

  @override
  Future<void> updateProfile(AthleteProfile profile) async => _profile.value = profile;

  @override
  void dispose() {
    _status.dispose();
    _profile.dispose();
  }
}
