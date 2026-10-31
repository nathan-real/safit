import 'package:flutter_test/flutter_test.dart';

import 'package:safit/models/test_protocol.dart';
import 'package:safit/models/test_session.dart';
import 'package:safit/services/test/mock_test_service.dart';

void main() {
  // testWidgets fournit une horloge simulée : tester.pump avance le temps.
  testWidgets('Un test passe par armé → en cours → décélération → terminé',
      (tester) async {
    final service = MockTestService();
    addTearDown(service.dispose);

    await service.arm(TestProtocol.incremental);
    expect(service.session.value!.phase, TestPhase.armed);
    expect(service.session.value!.targetCadenceRpm, 40);

    await tester.pump(const Duration(seconds: 3));
    final running = service.session.value!;
    expect(running.phase, TestPhase.running);
    expect(running.cadenceRpm, closeTo(40, 5));
    expect(running.heartRateBpm, isNotNull);

    await tester.pump(const Duration(seconds: 61));
    expect(service.session.value!.targetCadenceRpm, 50);

    await service.stop();
    expect(service.session.value!.phase, TestPhase.deceleration);

    await tester.pump(const Duration(seconds: 10));
    expect(service.session.value!.phase, TestPhase.finished);
    expect(service.session.value!.cadenceRpm, 0);
  });

  testWidgets('Arrêter avant le premier trait annule le test', (tester) async {
    final service = MockTestService();
    addTearDown(service.dispose);

    await service.arm(TestProtocol.subMaximal);
    await service.stop();
    expect(service.session.value!.phase, TestPhase.aborted);
  });
}
