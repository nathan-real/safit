import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safit/app.dart';
import 'package:safit/services/app_services.dart';
import 'package:safit/services/storage/account_service.dart';
import 'package:safit/services/storage/mock_account_service.dart';

void main() {
  late ServiceRegistry services;

  tearDown(() => services.dispose());

  /// Le bouton peut être sous le clavier ou hors de l'écran : on le fait défiler.
  Future<void> tapLast(WidgetTester tester, String text) async {
    final button = find.text(text).last;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
  }

  testWidgets('Premier lancement : création du profil puis accès à l\'app', (tester) async {
    services = ServiceRegistry.mock(live: false, account: AccountStatus.noAccount);
    await tester.pumpWidget(SafitApp(services: services));
    expect(find.text('Créer mon profil'), findsWidgets);

    // Champs obligatoires vides : on reste sur l'écran.
    await tapLast(tester, 'Créer mon profil');
    await tester.pump();
    expect(find.text('Obligatoire'), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('firstName')), 'Hugo');
    await tester.enterText(find.byKey(const Key('lastName')), 'Durand');
    await tester.enterText(find.byKey(const Key('password')), 'velo');
    await tester.enterText(find.byKey(const Key('confirm')), 'autre');
    await tapLast(tester, 'Créer mon profil');
    await tester.pump();
    expect(find.text('Les mots de passe sont différents'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('confirm')), 'velo');
    await tapLast(tester, 'Créer mon profil');
    await tester.pumpAndSettle();
    expect(find.text('Bonjour Hugo 👋'), findsOneWidget);
    expect(services.account.status.value, AccountStatus.loggedIn);
  });

  testWidgets('Connexion : mauvais puis bon mot de passe', (tester) async {
    services = ServiceRegistry.mock(live: false, account: AccountStatus.loggedOut);
    await tester.pumpWidget(SafitApp(services: services));
    expect(find.text('Bonjour Léa'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('loginPassword')), 'faux');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Mot de passe incorrect'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('loginPassword')), MockAccountService.password);
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour Léa 👋'), findsOneWidget);
  });

  testWidgets('Profil : modification puis déconnexion', (tester) async {
    services = ServiceRegistry.mock(live: false);
    await tester.pumpWidget(SafitApp(services: services));
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Léa Martin'), findsOneWidget);
    expect(find.text('24 ans'), findsOneWidget);

    await tester.tap(find.text('Modifier mon profil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('age')), '25');
    await tapLast(tester, 'Enregistrer');
    await tester.pumpAndSettle();
    expect(find.text('25 ans'), findsOneWidget);

    await tapLast(tester, 'Se déconnecter');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se déconnecter').last);
    await tester.pumpAndSettle();
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
