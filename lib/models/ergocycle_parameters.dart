/// Caractéristiques de l'ergocycle utiles au calcul de la force et de la puissance.
class ErgocycleParameters {
  const ErgocycleParameters({
    required this.flywheelMassKg,
    required this.flywheelCircumferenceM,
    required this.flywheelTurnsPerPedalTurn,
    required this.provisional,
  });

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

  /// Vrai tant que les valeurs ne sont pas celles de l'ergocycle réel.
  final bool provisional;
}
