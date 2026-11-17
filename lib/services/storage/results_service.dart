import 'package:flutter/foundation.dart';

import '../../models/test_recording.dart';
import '../../models/test_result.dart';

/// Historique des tests enregistrés.
/// Implémentations : [MockResultsService] et [LocalResultsService].
abstract interface class ResultsService {
  /// Prévient quand l'historique change (nouveau test enregistré).
  Listenable get changes;

  /// Tous les résultats, du plus récent au plus ancien.
  Future<List<TestResult>> listResults();
  Future<TestResult?> getResult(String id);

  /// Enregistre un résultat, avec ses mesures brutes si on les a (export CSV).
  Future<void> save(TestResult result, {TestRecording? recording});

  /// Mesures brutes d'un test, ou null si elles n'ont pas été gardées.
  Future<TestRecording?> getRecording(String id);
}
