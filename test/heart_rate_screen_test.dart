import 'package:flutter_test/flutter_test.dart';

import 'package:safit/app.dart';
import 'package:safit/services/app_services.dart';

void main() {
  late ServiceRegistry services;

  setUp(() => services = ServiceRegistry.mock(live: false));
  tearDown(() => services.dispose());

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polar H10'));
    await tester.pumpAndSettle();
  }

  testWidgets('Affiche la FC, la batterie et permet de déconnecter', (tester) async {
    await openScreen(tester);

    expect(find.text('72'), findsOneWidget);
    expect(find.text('Batterie 78 %'), findsOneWidget);

    await tester.tap(find.text('Déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Rechercher'), findsOneWidget);
  });

  testWidgets('Rechercher puis connecter une ceinture', (tester) async {
    await services.heartRate.disconnect();
    await openScreen(tester);

    await tester.tap(find.text('Rechercher'));
    await tester.pump();
    expect(find.text('Recherche de ceintures…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Polar H10 A1B2C3D4'));
    await tester.pump();
    expect(find.text('Connexion…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Fréquence cardiaque en direct'), findsOneWidget);
  });

  testWidgets('Accessible depuis les réglages', (tester) async {
    await tester.pumpWidget(SafitApp(services: services));
    await tester.tap(find.byTooltip('Réglages').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polar H10'));
    await tester.pumpAndSettle();
    expect(find.text('Bien porter la ceinture'), findsOneWidget);
  });
}
