import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/test_protocol.dart';
import '../../models/test_result.dart';
import '../screens/results/test_result_screen.dart';
import 'protocol_icon.dart';
import 'safit_list_tile.dart';

/// Un test de l'historique : type, date et chiffres clés. Ouvre son bilan.
class ResultTile extends StatelessWidget {
  const ResultTile(this.result, {super.key});

  final TestResult result;

  @override
  Widget build(BuildContext context) {
    // Les chiffres qui comptent pour chaque type de test.
    final metrics = switch (result.protocol) {
      TestProtocol.frictionCalibration => [
          if (result.frictionForceN != null) '${result.frictionForceN!.toStringAsFixed(1)} N',
        ],
      TestProtocol.forceVelocity => [
          if (result.peakPowerW != null) 'Pmax ${result.peakPowerW!.round()} W',
        ],
      TestProtocol.subMaximal || TestProtocol.incremental => [
          if (result.avgPowerW != null) '${result.avgPowerW!.round()} W',
          if (result.avgHeartRateBpm != null) '${result.avgHeartRateBpm} bpm',
        ],
    };
    return SafitListTile(
      icon: result.protocol.icon,
      title: result.protocol.title,
      subtitle: formatDateTime(result.date),
      footer: Text(metrics.join(' · ')),
      onTap: () => TestResultScreen.open(context, result),
    );
  }
}
