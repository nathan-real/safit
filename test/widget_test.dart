import 'package:flutter_test/flutter_test.dart';

import 'package:safit/app.dart';

void main() {
  testWidgets('La coque navigue entre les onglets et ouvre les réglages',
      (tester) async {
    await tester.pumpWidget(const SafitApp());

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
    await tester.pumpWidget(const SafitApp());

    await tester.tap(find.text('Nouveau test'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir un test'), findsOneWidget);
  });
}
