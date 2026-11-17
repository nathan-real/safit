import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../models/athlete_profile.dart';
import 'account_service.dart';
import 'local_store.dart';

/// Compte enregistré dans un fichier du téléphone. Le mot de passe n'est
/// jamais gardé en clair : seulement son empreinte (SHA-256 avec un sel).
///
/// C'est une protection locale (qui utilise l'app sur ce téléphone), pas
/// une sécurité de niveau bancaire : il n'y a pas de serveur.
class LocalAccountService implements AccountService {
  LocalAccountService(this._store);

  static const _file = 'account';

  final LocalStore _store;
  final _status = ValueNotifier(AccountStatus.loading);
  final _profile = ValueNotifier<AthleteProfile?>(null);
  String? _salt;
  String? _hash;

  @override
  ValueListenable<AccountStatus> get status => _status;

  @override
  ValueListenable<AthleteProfile?> get profile => _profile;

  @override
  Future<void> load() async {
    final json = await _store.read(_file);
    if (json is! Map<String, Object?>) {
      _status.value = AccountStatus.noAccount;
      return;
    }
    _profile.value = AthleteProfile.fromJson(json['profile']! as Map<String, Object?>);
    _salt = json['salt'] as String?;
    _hash = json['passwordHash'] as String?;
    _status.value = AccountStatus.loggedOut;
  }

  @override
  Future<void> create(AthleteProfile profile, String password) async {
    final random = Random.secure();
    _salt = base64Encode(List.generate(16, (_) => random.nextInt(256)));
    _hash = _hashOf(password, _salt!);
    _profile.value = profile;
    await _save();
    _status.value = AccountStatus.loggedIn;
  }

  @override
  Future<bool> login(String password) async {
    final salt = _salt;
    if (salt == null || _hashOf(password, salt) != _hash) return false;
    _status.value = AccountStatus.loggedIn;
    return true;
  }

  @override
  Future<void> logout() async => _status.value = AccountStatus.loggedOut;

  @override
  Future<void> updateProfile(AthleteProfile profile) async {
    _profile.value = profile;
    await _save();
  }

  Future<void> _save() => _store.write(_file, {
        'profile': _profile.value!.toJson(),
        'salt': _salt,
        'passwordHash': _hash,
      });

  static String _hashOf(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  @override
  void dispose() {
    _status.dispose();
    _profile.dispose();
  }
}
