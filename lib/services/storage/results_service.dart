import 'package:flutter/foundation.dart';

import '../../models/test_result.dart';

/// Historique des tests enregistrés.
/// Implémentations : [MockResultsService], puis un stockage local réel.
abstract interface class ResultsService {
  /// Prévient quand l'historique change (nouveau test enregistré).
  Listenable get changes;

  /// Tous les résultats, du plus récent au plus ancien.
  Future<List<TestResult>> listResults();
  Future<TestResult?> getResult(String id);
  Future<void> save(TestResult result);
}
