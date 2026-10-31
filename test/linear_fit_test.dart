import 'package:flutter_test/flutter_test.dart';

import 'package:safit/domain/signal_processing/linear_fit.dart';

void main() {
  test('retrouve la pente et l\'ordonnée d\'une droite parfaite', () {
    final fit = fitLine([for (var t = 0.0; t <= 7; t += 0.25) (t, 90 - 12 * t)])!;
    expect(fit.slope, closeTo(-12, 1e-9));
    expect(fit.intercept, closeTo(90, 1e-9));
    expect(fit.r2, closeTo(1, 1e-9));
  });

  test('une courbe irrégulière donne une régularité plus faible', () {
    final points = [(0.0, 90.0), (1.0, 60.0), (2.0, 75.0), (3.0, 40.0), (4.0, 50.0)];
    final fit = fitLine(points)!;
    expect(fit.slope, lessThan(0));
    expect(fit.r2, lessThan(0.9));
  });

  test('pas de droite avec moins de deux points', () {
    expect(fitLine([]), isNull);
    expect(fitLine([(1.0, 2.0)]), isNull);
  });
}
