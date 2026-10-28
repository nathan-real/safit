import 'package:flutter/foundation.dart';

import '../../models/heart_rate.dart';

/// Accès à la ceinture cardiaque (Polar H10).
/// Implémentations : [MockHeartRateService], puis la vraie version Bluetooth.
abstract interface class HeartRateService {
  /// État courant (connexion, FC, batterie), observable par l'interface.
  ValueListenable<HeartRateState> get state;

  /// Toutes les mesures reçues, à enregistrer pendant un test.
  Stream<HeartRateSample> get samples;

  Future<void> scan();
  Future<void> connect(HeartRateDevice device);
  Future<void> disconnect();
  void dispose();
}
