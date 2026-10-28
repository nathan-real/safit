import 'package:flutter/foundation.dart';

import '../../models/test_protocol.dart';
import '../../models/test_session.dart';

/// Déroulement d'un test : armement, mesure en direct, décélération, fin.
/// Implémentations : [MockTestService], puis la version branchée
/// sur la caméra et la ceinture.
abstract interface class TestDataService {
  /// Test en cours, ou null s'il n'y en a pas.
  ValueListenable<TestSession?> get session;

  /// Prépare le test : la mesure démarrera aux premiers traits détectés.
  Future<void> arm(TestProtocol protocol);

  /// Fin de l'effort : passe en décélération (ou annule si pas démarré).
  Future<void> stop();

  /// Abandon du test, sans résultat.
  Future<void> abort();

  /// Oublie le test terminé.
  void reset();
  void dispose();
}
