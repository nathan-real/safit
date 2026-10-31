import 'package:flutter_test/flutter_test.dart';

import 'package:safit/domain/physics/power_model.dart';
import 'package:safit/domain/results/test_summary.dart';
import 'package:safit/models/ergocycle_parameters.dart';
import 'package:safit/models/test_protocol.dart';
import 'package:safit/models/test_session.dart';

/// Ergocycle aux chiffres ronds pour vérifier les calculs à la main :
/// 1 tour de pédale = 2 tours de volant, volant de 3 m de tour, 20 kg.
const _ergo = ErgocycleParameters(
  flywheelMassKg: 20,
  flywheelCircumferenceM: 3,
  flywheelTurnsPerPedalTurn: 2,
  provisional: false,
);

void main() {
  group('Formules', () {
    test('vitesse du bord du volant', () {
      // 60 tr/min de pédale = 2 tr/s de volant = 6 m/s au bord.
      expect(rimSpeed(60, _ergo), closeTo(6, 1e-9));
    });

    test('force de friction = masse × décélération du bord (F = m·a)', () {
      // -10 tr/min/s de pédale = -1 m/s² au bord ; 20 kg × 1 m/s² = 20 N.
      expect(frictionForce(-10, _ergo), closeTo(20, 1e-9));
    });

    test('puissance = force × vitesse', () {
      // 20 N × 6 m/s = 120 W.
      expect(mechanicalPower(60, 20, _ergo), closeTo(120, 1e-9));
    });
  });

  test('bilan d\'un test incrémental : moyennes, force, puissance par palier', () {
    final session = TestSession(
      protocol: TestProtocol.incremental,
      phase: TestPhase.finished,
      decelerationSlope: -10,
      decelerationR2: 0.99,
      samples: [
        for (var i = 0; i < 10; i++)
          TestSample(
            elapsed: Duration(seconds: i),
            cadenceRpm: i < 5 ? 40 : 60,
            heartRateBpm: i < 5 ? 100 : 120,
            stageIndex: i < 5 ? 0 : 1,
            targetCadenceRpm: i < 5 ? 40 : 60,
          ),
      ],
    );

    final result = summarizeTest(session, _ergo, id: 'x', date: DateTime(2026));

    expect(result.duration, const Duration(seconds: 9));
    expect(result.avgCadenceRpm, closeTo(50, 1e-9));
    expect(result.avgHeartRateBpm, 110);
    expect(result.maxHeartRateBpm, 120);
    expect(result.frictionForceN, closeTo(20, 1e-9));
    expect(result.avgPowerW, closeTo(100, 1e-9)); // 20 N × 5 m/s
    expect(result.provisionalErgocycle, isFalse);

    expect(result.stages, hasLength(2));
    expect(result.stages[1].targetCadenceRpm, 60);
    expect(result.stages[1].avgHeartRateBpm, 120);
    expect(result.stages[1].avgPowerW, closeTo(120, 1e-9));
  });
}
