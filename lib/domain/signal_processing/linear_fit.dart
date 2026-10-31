/// Droite ajustée par moindres carrés : y = pente × x + ordonnée.
class LinearFit {
  const LinearFit({required this.slope, required this.intercept, required this.r2});

  final double slope;
  final double intercept;

  /// Coefficient de détermination (0..1) : 1 = points parfaitement alignés.
  final double r2;
}

/// Ajuste une droite sur des points (x, y). Null s'il y a moins de 2 points
/// ou si tous les x sont identiques.
LinearFit? fitLine(List<(double, double)> points) {
  final n = points.length;
  if (n < 2) return null;
  var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumXY = 0.0;
  for (final (x, y) in points) {
    sumX += x;
    sumY += y;
    sumXX += x * x;
    sumXY += x * y;
  }
  final denominator = n * sumXX - sumX * sumX;
  if (denominator == 0) return null;
  final slope = (n * sumXY - sumX * sumY) / denominator;
  final intercept = (sumY - slope * sumX) / n;

  final meanY = sumY / n;
  var residual = 0.0, total = 0.0;
  for (final (x, y) in points) {
    final predicted = slope * x + intercept;
    residual += (y - predicted) * (y - predicted);
    total += (y - meanY) * (y - meanY);
  }
  return LinearFit(
    slope: slope,
    intercept: intercept,
    r2: total == 0 ? 1 : 1 - residual / total,
  );
}
