import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safit/app.dart';
import 'package:safit/models/test_protocol.dart';
import 'package:safit/services/app_services.dart';

void main() {
  late ServiceRegistry services;

  setUp(() => services = ServiceRegistry.mock(live: false));
  tearDown(() => services.dispose());

  Future<void> openFlow(WidgetTester tester, TestProtocol protocol) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.tap(find.text('Tests'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(protocol.title), 100);
    await tester.tap(find.text(protocol.title));
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
  }

  testWidgets('Le parcours enchaîne les 5 étapes jusqu\'à « Tout est prêt »',
      (tester) async {
    await openFlow(tester, TestProtocol.incremental);

    expect(find.text('Présentation'), findsOneWidget);
    expect(find.text(TestProtocol.incremental.procedure.first), findsOneWidget);

    await tapContinue(tester);
    expect(find.text('Préparation'), findsOneWidget);

    await tapContinue(tester);
    expect(find.text('Traits détectés'), findsOneWidget);

    await tapContinue(tester);
    expect(find.text('Fréquence cardiaque en direct'), findsOneWidget);

    await tapContinue(tester);
    expect(find.text('Tout est prêt !'), findsOneWidget);
    expect(find.text('Commencer le test'), findsOneWidget);
  });

  testWidgets('Le retour revient à l\'étape précédente', (tester) async {
    await openFlow(tester, TestProtocol.subMaximal);
    await tapContinue(tester);
    expect(find.text('Préparation'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Présentation'), findsOneWidget);
  });

  testWidgets('Abandonner demande confirmation puis ferme le parcours',
      (tester) async {
    await openFlow(tester, TestProtocol.forceVelocity);

    await tester.tap(find.byTooltip('Abandonner'));
    await tester.pumpAndSettle();
    expect(find.text('Abandonner le test ?'), findsOneWidget);

    await tester.tap(find.text('Continuer la préparation'));
    await tester.pumpAndSettle();
    expect(find.text('Présentation'), findsOneWidget);

    await tester.tap(find.byTooltip('Abandonner'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Abandonner'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir un test'), findsOneWidget);
  });

  testWidgets('Sans ceinture, on ne peut continuer que si le test le permet',
      (tester) async {
    await services.heartRate.disconnect();
    await openFlow(tester, TestProtocol.incremental);
    for (var i = 0; i < 3; i++) {
      await tapContinue(tester);
    }
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Continuer'), matching: find.byWidgetPredicate((w) => w is FilledButton)),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Le test force-vitesse peut se faire sans ceinture', (tester) async {
    await services.heartRate.disconnect();
    await openFlow(tester, TestProtocol.forceVelocity);
    for (var i = 0; i < 3; i++) {
      await tapContinue(tester);
    }
    await tester.tap(find.text('Continuer sans ceinture'));
    await tester.pumpAndSettle();
    expect(find.text('Tout est prêt !'), findsOneWidget);
  });
}
