/// Les protocoles de test proposés, tels que décrits par le Pr Arsac.
enum TestProtocol {
  subMaximal(
    title: 'Test sous-maximal',
    shortTitle: 'Sous-max',
    description: '2 paliers à charge différente, avec repos entre les deux.',
    objective: 'Estimer l\'aptitude aérobie : la pente fréquence cardiaque / '
        'puissance est un indicateur de la VO2max.',
    duration: '2 × 5 min',
    requiresHeartRate: true,
    procedure: [
      'Pédalez 5 min à une allure régulière.',
      'Au signal, arrêtez de pédaler : le volant ralentit seul.',
      'Reposez-vous pendant que la courroie est resserrée.',
      'Pédalez à nouveau 5 min, puis arrêtez au signal.',
    ],
  ),
  incremental(
    title: 'Test incrémental',
    shortTitle: 'Incrémental',
    description: 'Paliers de cadence de 40 à 80 rpm, environ 1 min chacun. '
        'Un bip signale chaque changement.',
    objective: 'Suivre la réponse cardiaque quand l\'effort augmente.',
    duration: '≈ 7 min + 2 min récup.',
    requiresHeartRate: true,
    procedure: [
      'Commencez à pédaler à 40 rpm.',
      'À chaque bip (environ toutes les minutes), augmentez de 10 rpm, '
          'jusqu\'à 80 rpm.',
      'Votre cadence s\'affiche : restez proche de la cible.',
      'Au dernier signal, arrêtez de pédaler et récupérez 2 min.',
    ],
  ),
  forceVelocity(
    title: 'Test force-vitesse',
    shortTitle: 'Force-vitesse',
    description: 'Sprint départ arrêté, effort maximal. '
        'La mesure démarre au premier coup de pédale.',
    objective: 'Mesurer la puissance maximale et le profil force-vitesse.',
    duration: '6 – 8 s',
    requiresHeartRate: false,
    procedure: [
      'Placez-vous à l\'arrêt, une pédale en haut.',
      'Sprintez au maximum pendant 6 à 8 secondes.',
      'Au signal, arrêtez de pédaler : le volant ralentit seul.',
    ],
  ),
  frictionCalibration(
    title: 'Calibration friction',
    shortTitle: 'Calibration',
    description: 'Lancez le volant puis arrêtez de pédaler : '
        'la décélération donne la force de friction.',
    objective: 'Étalonner la force de freinage de la courroie.',
    duration: '< 1 min',
    requiresHeartRate: false,
    procedure: [
      'Pédalez quelques secondes pour lancer le volant.',
      'Arrêtez de pédaler et ne touchez plus les pédales.',
      'La mesure s\'arrête quand le volant est immobile.',
    ],
  );

  const TestProtocol({
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.objective,
    required this.duration,
    required this.requiresHeartRate,
    required this.procedure,
  });

  final String title;

  /// Libellé court pour les filtres et les puces.
  final String shortTitle;
  final String description;
  final String objective;

  /// Durée approximative, affichée telle quelle.
  final String duration;

  /// Faux si le test reste exploitable sans ceinture cardiaque.
  final bool requiresHeartRate;

  /// Déroulement du test, étape par étape, tel qu'expliqué à l'utilisateur.
  final List<String> procedure;
}
