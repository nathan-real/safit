import 'package:flutter/foundation.dart';

import '../../models/athlete_profile.dart';
import 'profile_service.dart';

/// Profil fictif, gardé en mémoire.
class MockProfileService implements ProfileService {
  MockProfileService({bool withSampleProfile = true}) {
    if (withSampleProfile) _profile.value = _sample;
  }

  static const _sample = AthleteProfile(
    firstName: 'Léa',
    lastName: 'Martin',
    age: 24,
    weightKg: 65,
    heightCm: 170,
    sport: 'Cyclisme',
    goal: 'Améliorer l\'endurance',
  );

  final _profile = ValueNotifier<AthleteProfile?>(null);

  @override
  ValueListenable<AthleteProfile?> get profile => _profile;

  @override
  Future<void> save(AthleteProfile profile) async => _profile.value = profile;

  @override
  void dispose() => _profile.dispose();
}
