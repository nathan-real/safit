import '../../models/ergocycle_parameters.dart';

// Méthode du Pr Arsac : quand le sujet arrête de pédaler, seul le frottement
// de la courroie freine le volant. La décélération du bord du volant,
// multipliée par sa masse, donne la force de friction (F = m·a). Pendant le
// test, la puissance est cette force multipliée par la vitesse du bord du volant.
//
// Les cadences et décélérations sont exprimées « côté pédale » (tr/min, tr/min/s),
// comme ailleurs dans l'app ; on passe au volant avec le rapport de transmission.

/// Vitesse du bord du volant (m/s) pour une cadence de pédalage (tr/min).
double rimSpeed(double cadenceRpm, ErgocycleParameters ergo) =>
    cadenceRpm * ergo.flywheelTurnsPerPedalTurn * ergo.flywheelCircumferenceM / 60;

/// Force de friction (N) à partir de la pente de décélération (tr/min par seconde,
/// négative ou positive : seule sa valeur absolue compte).
double frictionForce(double decelerationRpmPerSecond, ErgocycleParameters ergo) {
  final rimDeceleration = rimSpeed(decelerationRpmPerSecond.abs(), ergo); // m/s²
  return ergo.flywheelMassKg * rimDeceleration;
}

/// Puissance mécanique (W) dissipée contre la friction à une cadence donnée.
double mechanicalPower(double cadenceRpm, double frictionForceN, ErgocycleParameters ergo) =>
    frictionForceN * rimSpeed(cadenceRpm, ergo);
