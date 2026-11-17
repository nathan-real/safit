import 'package:flutter_test/flutter_test.dart';

import 'package:safit/domain/results/csv_export.dart';
import 'package:safit/models/test_protocol.dart';
import 'package:safit/models/test_recording.dart';
import 'package:safit/models/test_result.dart';
import 'package:safit/models/test_session.dart';

void main() {
  final result = TestResult(
    id: 'x',
    protocol: TestProtocol.frictionCalibration,
    date: DateTime(2026, 11, 17, 9, 5),
    duration: const Duration(seconds: 5),
    frictionForceN: 34.25,
  );

  test('Mesures regroupées seconde par seconde', () {
    final samples = [
      for (var ms = 250; ms <= 2000; ms += 250)
        TestSample(elapsed: Duration(milliseconds: ms), cadenceRpm: ms < 1000 ? 80 : 90, heartRateBpm: 100),
    ];
    final seconds = perSecond(samples);
    expect(seconds.map((s) => s.second), [0, 1, 2]);
    expect(seconds[0].cadenceRpm, 80);
    expect(seconds[1].cadenceRpm, 90);
    expect(seconds[0].heartRateBpm, 100);
  });

  test('CSV : bilan, mesures et décélération, format Excel français', () {
    const recording = TestRecording([
      RecordedBout(
        samples: [
          TestSample(elapsed: Duration(milliseconds: 250), cadenceRpm: 89.5, heartRateBpm: 120),
          TestSample(elapsed: Duration(milliseconds: 500), cadenceRpm: 90.5, heartRateBpm: 122),
        ],
        decelerationCurve: [(0.0, 90.0), (0.5, 84.25)],
      ),
    ]);
    final csv = buildTestCsv(result, recording: recording, athlete: 'Léa Martin');
    final lines = csv.split('\r\n');

    expect(lines, contains('Protocole;${TestProtocol.frictionCalibration.title}'));
    expect(lines, contains('Date;2026-11-17 09:05'));
    expect(lines, contains('Athlète;Léa Martin'));
    expect(lines, contains('Force de friction (N);34,25'));
    expect(lines, contains('1;0;90;121;;'));
    expect(lines, contains('1;0,5;84,25'));
    expect(csvFileName(result), 'safit_frictionCalibration_2026-11-17_09-05.csv');
  });

  test('CSV sans mesures brutes : seulement le bilan', () {
    final csv = buildTestCsv(result);
    expect(csv, isNot(contains('Mesures seconde par seconde')));
    expect(csv, contains('Force de friction (N);34,25'));
  });
}
