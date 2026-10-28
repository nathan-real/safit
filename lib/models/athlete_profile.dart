/// Informations sur l'athlète qui passe les tests.
class AthleteProfile {
  const AthleteProfile({
    required this.firstName,
    required this.lastName,
    this.age,
    this.weightKg,
    this.heightCm,
    this.sport,
    this.goal,
  });

  final String firstName;
  final String lastName;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final String? sport;
  final String? goal;

  String get fullName => '$firstName $lastName';
}
