import '../../models/test_protocol.dart';
import '../../models/test_result.dart';
import 'results_service.dart';

/// Historique fictif, gardé en mémoire.
class MockResultsService implements ResultsService {
  MockResultsService({bool withSampleData = true}) {
    if (withSampleData) _results.addAll(_sampleData());
  }

  final List<TestResult> _results = [];

  @override
  Future<List<TestResult>> listResults() async {
    return [..._results]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<TestResult?> getResult(String id) async {
    for (final r in _results) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<void> save(TestResult result) async => _results.add(result);

  static List<TestResult> _sampleData() {
    final now = DateTime.now();
    DateTime daysAgo(int days, int hour, int minute) =>
        DateTime(now.year, now.month, now.day - days, hour, minute);

    return [
      TestResult(
        id: 'r5',
        protocol: TestProtocol.incremental,
        date: daysAgo(1, 14, 32),
        duration: const Duration(minutes: 7, seconds: 12),
        avgPowerW: 182,
        avgHeartRateBpm: 154,
        avgCadenceRpm: 60,
        frictionForceN: 34.2,
      ),
      TestResult(
        id: 'r4',
        protocol: TestProtocol.subMaximal,
        date: daysAgo(4, 16, 3),
        duration: const Duration(minutes: 10, seconds: 4),
        avgPowerW: 138,
        avgHeartRateBpm: 128,
        avgCadenceRpm: 90,
        frictionForceN: 25.1,
      ),
      TestResult(
        id: 'r3',
        protocol: TestProtocol.forceVelocity,
        date: daysAgo(6, 10, 14),
        duration: const Duration(seconds: 7),
        peakPowerW: 742,
        avgCadenceRpm: 112,
        frictionForceN: 61.8,
      ),
      TestResult(
        id: 'r2',
        protocol: TestProtocol.frictionCalibration,
        date: daysAgo(12, 9, 45),
        duration: const Duration(seconds: 38),
        frictionForceN: 34.2,
      ),
      TestResult(
        id: 'r1',
        protocol: TestProtocol.incremental,
        date: daysAgo(20, 15, 20),
        duration: const Duration(minutes: 7, seconds: 5),
        avgPowerW: 176,
        avgHeartRateBpm: 148,
        avgCadenceRpm: 60,
        frictionForceN: 33.9,
      ),
    ];
  }
}
