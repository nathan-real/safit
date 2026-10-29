import 'package:flutter_test/flutter_test.dart';

import 'package:safit/app.dart';
import 'package:safit/models/test_protocol.dart';
import 'package:safit/services/app_services.dart';

void main() {
  late ServiceRegistry services;

  setUp(() => services = ServiceRegistry.mock(live: false));
  tearDown(() => services.dispose());

  testWidgets('La coque navigue entre les onglets et ouvre les réglages',
      (tester) async {
    await tester.pumpWidget(SafitApp(services: services));

    expect(find.text('Nouveau test'), findsOneWidget);

    await tester.tap(find.text('Tests'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir un test'), findsOneWidget);

    await tester.tap(find.text('Résultats'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat'), findsOneWidget);

    await tester.tap(find.byTooltip('Réglages').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Mode expert'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Mode expert'), findsNothing);
  });

  testWidgets('« Nouveau test » mène à l\'onglet Tests', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));

    await tester.tap(find.text('Nouveau test'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir un test'), findsOneWidget);
  });

  testWidgets('L\'accueil affiche l\'état des capteurs simulés', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Léa 👋'), findsOneWidget);
    expect(find.text('Connectée · 72 bpm'), findsOneWidget);
    expect(find.text('Prête · 240 fps'), findsOneWidget);
    expect(find.text('Test incrémental'), findsOneWidget);
  });

  testWidgets('Chaque test affiche son objectif et sa durée', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.tap(find.text('Tests'));
    await tester.pumpAndSettle();

    for (final protocol in TestProtocol.values) {
      await tester.scrollUntilVisible(find.text(protocol.duration), 100);
      expect(find.text(protocol.objective), findsOneWidget);
      expect(find.text(protocol.duration), findsOneWidget);
    }

    await tester.tap(find.text(TestProtocol.frictionCalibration.title));
    await tester.pumpAndSettle();
    expect(find.text('Présentation'), findsOneWidget);
  });

  testWidgets('Les cartes capteurs ouvrent leurs écrans', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Polar H10'));
    await tester.pumpAndSettle();
    expect(find.text('Bien porter la ceinture'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caméra'));
    await tester.pumpAndSettle();
    expect(find.text('Réglage caméra'), findsOneWidget);
  });

  testWidgets('Un test récent annonce l\'écran de détail à venir', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test incrémental'));
    await tester.pump();
    expect(find.text('Bientôt disponible'), findsOneWidget);
  });
}
