import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safit/app.dart';
import 'package:safit/models/test_protocol.dart';
import 'package:safit/services/app_services.dart';
import 'package:safit/services/test/auto_test_service.dart';
import 'package:safit/services/test/mock_test_service.dart';
import 'package:safit/ui/screens/results/test_result_screen.dart';

void main() {
  late ServiceRegistry services;

  setUp(() => services = ServiceRegistry.mock(live: false));
  tearDown(() => services.dispose());

  testWidgets('Historique : tous les tests, puis filtrés par type', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.tap(find.text('Résultats'));
    await tester.pumpAndSettle();

    final incremental = find.text(TestProtocol.incremental.title);
    expect(incremental, findsWidgets);

    await tester.tap(find.text(TestProtocol.forceVelocity.shortTitle));
    await tester.pumpAndSettle();
    expect(incremental, findsNothing);
    expect(find.text(TestProtocol.forceVelocity.title), findsOneWidget);

    await tester.tap(find.text(TestProtocol.forceVelocity.title));
    await tester.pumpAndSettle();
    expect(find.text('Puissance max'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Exporter (CSV)'),
      200,
      scrollable: find
          .descendant(of: find.byType(TestResultScreen), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Exporter (CSV)'), findsOneWidget);
  });

  testWidgets('Réglages : paramètres de l\'ergocycle enregistrés', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.tap(find.byTooltip('Réglages').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paramètres machine'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Valeurs provisoires'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('mass')), '18,5');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final saved = services.ergocycle.parameters.value;
    expect(saved.flywheelMassKg, 18.5);
    expect(saved.provisional, isFalse);
  });

  testWidgets('Réglages : tutoriels et mode expert', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.tap(find.byTooltip('Réglages').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tutoriels'));
    await tester.pumpAndSettle();
    expect(find.text('Installer le matériel'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Mode expert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mode expert'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnostic caméra'), findsOneWidget);
    await tester.ensureVisible(find.text('Mesurés par la caméra'));
    expect(find.text('Mesurés par la caméra'), findsOneWidget);
  });

  test('Test réel si la caméra est prête, simulé sinon', () async {
    var ready = false;
    final real = MockTestService();
    final simulated = MockTestService();
    final auto = AutoTestService(real: real, simulated: simulated, cameraReady: () => ready);

    await auto.arm(TestProtocol.frictionCalibration);
    expect(simulated.session.value, isNotNull);
    expect(real.session.value, isNull);
    expect(auto.session.value, same(simulated.session.value));

    ready = true;
    await auto.arm(TestProtocol.frictionCalibration);
    expect(simulated.session.value, isNull);
    expect(real.session.value, isNotNull);
    expect(auto.session.value, same(real.session.value));
    auto.dispose();
  });
}
