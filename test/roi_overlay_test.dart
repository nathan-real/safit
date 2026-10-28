import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safit/ui/screens/expert/roi_overlay.dart';

void main() {
  // Le rectangle est dans une page qui défile, comme sur l'écran du prototype :
  // le glisser doit le déplacer, sans faire défiler la page.
  Future<(ScrollController, Rect Function())> pumpOverlay(WidgetTester tester) async {
    var roi = const Rect.fromLTWH(0.2, 0.4, 0.6, 0.15);
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              // Align : sinon la liste étire l'aperçu à toute la largeur.
              Align(
                alignment: Alignment.topLeft,
                child: StatefulBuilder(
                  builder: (context, setState) => SizedBox(
                    width: 400,
                    height: 400,
                    child: RoiOverlay(roi: roi, onChanged: (r) => setState(() => roi = r)),
                  ),
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    return (scroll, () => roi);
  }

  testWidgets('Glisser le rectangle le déplace sans faire défiler la page', (tester) async {
    final (scroll, roi) = await pumpOverlay(tester);
    final before = roi();

    // Centre du rectangle : (0.5 × 400, 0.475 × 400) dans la page.
    await tester.dragFrom(const Offset(200, 190), const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(scroll.offset, 0);
    expect(roi().top, closeTo(before.top + 100 / 400, 0.01));
    expect(roi().size, before.size);
  });

  testWidgets('La poignée redimensionne le rectangle', (tester) async {
    final (scroll, roi) = await pumpOverlay(tester);
    final before = roi();

    // Poignée : coin bas-droit, (0.8 × 400, 0.55 × 400).
    await tester.dragFrom(const Offset(320, 220), const Offset(-40, 40));
    await tester.pumpAndSettle();

    expect(scroll.offset, 0);
    expect(roi().topLeft, before.topLeft);
    expect(roi().width, closeTo(before.width - 40 / 400, 0.01));
    expect(roi().height, closeTo(before.height + 40 / 400, 0.01));
  });

  testWidgets('Le rectangle ne sort pas de l\'image', (tester) async {
    final (_, roi) = await pumpOverlay(tester);

    await tester.dragFrom(const Offset(200, 190), const Offset(0, 1000));
    await tester.pumpAndSettle();

    expect(roi().bottom, closeTo(1.0, 0.001));
  });
}
