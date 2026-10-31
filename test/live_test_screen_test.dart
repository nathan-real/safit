import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safit/core/theme/app_theme.dart';
import 'package:safit/models/test_protocol.dart';
import 'package:safit/services/app_services.dart';
import 'package:safit/ui/screens/test_runner/live_test_screen.dart';

void main() {
  late ServiceRegistry services;

  setUp(() => services = ServiceRegistry.mock(live: false));
  tearDown(() => services.dispose());

  // Le test simulé envoie des valeurs toutes les 250 ms : on avance l'horloge
  // avec pump(durée) plutôt que pumpAndSettle, qui n'aurait jamais fini.
  Future<void> openLive(WidgetTester tester, TestProtocol protocol) async {
    await tester.pumpWidget(
      AppServices(
        registry: services,
        child: MaterialApp(theme: AppTheme.dark, home: LiveTestScreen(protocol: protocol)),
      ),
    );
    await tester.pump();
  }

  /// Retire l'écran avant la fin du test (et donc avant de libérer les services).
  Future<void> close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('Incrémental : attente, cible, palier, arrêt puis décélération', (tester) async {
    await openLive(tester, TestProtocol.incremental);
    expect(find.text('Commencez à pédaler'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Cible 40 rpm'), findsOneWidget);
    expect(find.text('Palier 1/5'), findsOneWidget);
    expect(
      find.textContaining(RegExp('Bonne cadence|Trop vite|Trop lent')),
      findsOneWidget,
    );
    expect(find.text('bpm'), findsOneWidget);

    await tester.tap(find.text('Arrêter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Arrêter le test ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Arrêter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Arrêtez de pédaler'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    expect(find.text('Mesure terminée'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Force-vitesse : « Sprintez ! » puis arrêt automatique', (tester) async {
    await openLive(tester, TestProtocol.forceVelocity);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Sprintez !'), findsOneWidget);
    expect(find.text('Durée du sprint'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    expect(find.text('Arrêtez de pédaler'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Sous-maximal : le temps restant est affiché', (tester) async {
    await openLive(tester, TestProtocol.subMaximal);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Temps restant'), findsOneWidget);
    expect(find.text('04:59'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Avant le départ, on peut annuler avec confirmation', (tester) async {
    await openLive(tester, TestProtocol.subMaximal);
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Annuler le test ?'), findsOneWidget);

    await tester.tap(find.text('Continuer le test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Commencez à pédaler'), findsOneWidget);
    await close(tester);
  });
}
