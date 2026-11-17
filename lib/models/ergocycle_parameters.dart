/// Caractéristiques de l'ergocycle utiles au calcul de la force et de la puissance.
class ErgocycleParameters {
  const ErgocycleParameters({
    required this.flywheelMassKg,
    required this.flywheelCircumferenceM,
    required this.flywheelTurnsPerPedalTurn,
    required this.provisional,
    this.marksPerFlywheelTurn = 8,
  });

  factory ErgocycleParameters.fromJson(Map<String, Object?> j) => ErgocycleParameters(
        flywheelMassKg: (j['flywheelMassKg'] as num).toDouble(),
        flywheelCircumferenceM: (j['flywheelCircumferenceM'] as num).toDouble(),
        flywheelTurnsPerPedalTurn: (j['flywheelTurnsPerPedalTurn'] as num).toDouble(),
        marksPerFlywheelTurn: j['marksPerFlywheelTurn'] as int? ?? 8,
        provisional: j['provisional'] as bool? ?? false,
      );

  /// Valeurs provisoires, en attendant le modèle exact de l'ergocycle du SMART :
  /// masse donnée par le Pr Arsac (22 kg), dimensions typiques d'un ergocycle
  /// à courroie de laboratoire (volant de 1,62 m de tour, 6 m parcourus par
  /// tour de pédale). À remplacer dès que possible.
  static const provisionalDefaults = ErgocycleParameters(
    flywheelMassKg: 22,
    flywheelCircumferenceM: 1.62,
    flywheelTurnsPerPedalTurn: 6 / 1.62,
    provisional: true,
  );

  final double flywheelMassKg;

  /// Tour du volant (m), là où frotte la courroie.
  final double flywheelCircumferenceM;

  /// Tours de volant pour un tour de pédale.
  final double flywheelTurnsPerPedalTurn;

  /// Nombre de traits noirs tracés sur le volant.
  final int marksPerFlywheelTurn;

  /// Vrai tant que les valeurs ne sont pas celles de l'ergocycle réel.
  final bool provisional;

  ErgocycleParameters copyWith({
    double? flywheelMassKg,
    double? flywheelCircumferenceM,
    double? flywheelTurnsPerPedalTurn,
    int? marksPerFlywheelTurn,
    bool? provisional,
  }) =>
      ErgocycleParameters(
        flywheelMassKg: flywheelMassKg ?? this.flywheelMassKg,
        flywheelCircumferenceM: flywheelCircumferenceM ?? this.flywheelCircumferenceM,
        flywheelTurnsPerPedalTurn: flywheelTurnsPerPedalTurn ?? this.flywheelTurnsPerPedalTurn,
        marksPerFlywheelTurn: marksPerFlywheelTurn ?? this.marksPerFlywheelTurn,
        provisional: provisional ?? this.provisional,
      );

  Map<String, Object?> toJson() => {
        'flywheelMassKg': flywheelMassKg,
        'flywheelCircumferenceM': flywheelCircumferenceM,
        'flywheelTurnsPerPedalTurn': flywheelTurnsPerPedalTurn,
        'marksPerFlywheelTurn': marksPerFlywheelTurn,
        'provisional': provisional,
      };
}
