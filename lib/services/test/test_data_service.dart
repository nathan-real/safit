import 'package:flutter/foundation.dart';

import '../../models/test_protocol.dart';
import '../../models/test_session.dart';

/// Déroulement d'un test : armement, mesure en direct, décélération, fin.
/// Implémentations : [MockTestService] (simulé), [RealTestService] (caméra et
/// ceinture) et [AutoTestService] (choisit entre les deux à chaque test).
abstract interface class TestDataService {
  /// Test en cours, ou null s'il n'y en a pas.
  ValueListenable<TestSession?> get session;

  /// Vrai si les mesures sont simulées (pas de caméra 240 i/s).
  bool get isSimulation;

  /// Prépare le test : la mesure démarrera aux premiers traits détectés.
  /// [bout] : numéro de l'essai (à partir de 0) pour les tests en plusieurs
  /// essais, comme le sous-maximal (2 essais à tension différente).
  Future<void> arm(TestProtocol protocol, {int bout = 0});

  /// Fin de l'effort : passe en décélération (ou annule si pas démarré).
  Future<void> stop();

  /// Abandon du test, sans résultat.
  Future<void> abort();

  /// Oublie le test terminé.
  void reset();
  void dispose();
}
