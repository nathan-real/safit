/// Les protocoles de test proposés, tels que décrits par le Pr Arsac.
enum TestProtocol {
  subMaximal(
    title: 'Test sous-maximal',
    shortTitle: 'Sous-max',
    description: '2 paliers à charge différente, avec repos entre les deux.',
    objective: 'Estimer l\'aptitude aérobie : la pente fréquence cardiaque / '
        'puissance est un indicateur de la VO2max.',
    duration: '2 × 5 min',
  ),
  incremental(
    title: 'Test incrémental',
    shortTitle: 'Incrémental',
    description: 'Paliers de cadence de 40 à 80 rpm, environ 1 min chacun. '
        'Un bip signale chaque changement.',
    objective: 'Suivre la réponse cardiaque quand l\'effort augmente.',
    duration: '≈ 7 min + 2 min récup.',
  ),
  forceVelocity(
    title: 'Test force-vitesse',
    shortTitle: 'Force-vitesse',
    description: 'Sprint départ arrêté, effort maximal. '
        'La mesure démarre au premier coup de pédale.',
    objective: 'Mesurer la puissance maximale et le profil force-vitesse.',
    duration: '6 – 8 s',
  ),
  frictionCalibration(
    title: 'Calibration friction',
    shortTitle: 'Calibration',
    description: 'Lancez le volant puis arrêtez de pédaler : '
        'la décélération donne la force de friction.',
    objective: 'Étalonner la force de freinage de la courroie.',
    duration: '< 1 min',
  );

  const TestProtocol({
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.objective,
    required this.duration,
  });

  final String title;

  /// Libellé court pour les filtres et les puces.
  final String shortTitle;
  final String description;
  final String objective;

  /// Durée approximative, affichée telle quelle.
  final String duration;
}
