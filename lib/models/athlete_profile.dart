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

  factory AthleteProfile.fromJson(Map<String, Object?> json) => AthleteProfile(
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        age: json['age'] as int?,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        sport: json['sport'] as String?,
        goal: json['goal'] as String?,
      );

  final String firstName;
  final String lastName;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final String? sport;
  final String? goal;

  String get fullName => '$firstName $lastName';

  Map<String, Object?> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'sport': sport,
        'goal': goal,
      };
}
