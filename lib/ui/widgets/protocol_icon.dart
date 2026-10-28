import 'package:flutter/material.dart';

import '../../models/test_protocol.dart';

/// Icône associée à chaque protocole (gardée côté interface, pas dans le modèle).
extension TestProtocolIcon on TestProtocol {
  IconData get icon => switch (this) {
        TestProtocol.subMaximal => Icons.bar_chart_rounded,
        TestProtocol.incremental => Icons.trending_up_rounded,
        TestProtocol.forceVelocity => Icons.bolt_rounded,
        TestProtocol.frictionCalibration => Icons.settings_suggest_outlined,
      };
}
