import 'package:flutter/foundation.dart';

import '../../models/test_recording.dart';
import '../../models/test_result.dart';
import 'local_store.dart';
import 'results_service.dart';

/// Historique enregistré sur le téléphone : un fichier pour la liste des
/// résultats, un fichier par test pour ses mesures brutes.
class LocalResultsService implements ResultsService {
  LocalResultsService(this._store);

  static const _file = 'results';
  static String _recordingFile(String id) => 'recording_$id';

  final LocalStore _store;
  final _revision = ValueNotifier(0);
  List<TestResult>? _cache;

  @override
  Listenable get changes => _revision;

  Future<List<TestResult>> _all() async {
    final cached = _cache;
    if (cached != null) return cached;
    final json = await _store.read(_file);
    return _cache = [
      if (json is List)
        for (final r in json) TestResult.fromJson(r! as Map<String, Object?>),
    ];
  }

  @override
  Future<List<TestResult>> listResults() async =>
      [...await _all()]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<TestResult?> getResult(String id) async {
    for (final r in await _all()) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<void> save(TestResult result, {TestRecording? recording}) async {
    final all = [...await _all(), result];
    if (recording != null) await _store.write(_recordingFile(result.id), recording.toJson());
    await _store.write(_file, [for (final r in all) r.toJson()]);
    _cache = all;
    _revision.value++;
  }

  @override
  Future<TestRecording?> getRecording(String id) async {
    final json = await _store.read(_recordingFile(id));
    return json is List ? TestRecording.fromJson(json) : null;
  }
}
