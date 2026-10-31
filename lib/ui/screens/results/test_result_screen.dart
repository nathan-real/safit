import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/test_protocol.dart';
import '../../../models/test_result.dart';
import '../../widgets/protocol_icon.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';

/// Bilan d'un test : à la fin d'un test, ou depuis l'historique.
class TestResultScreen extends StatelessWidget {
  const TestResultScreen({super.key, required this.result, this.justFinished = false});

  final TestResult result;

  /// Vrai juste après le test (affiche « Test terminé »).
  final bool justFinished;

  static Future<void> open(BuildContext context, TestResult result) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TestResultScreen(result: result)),
    );
  }

  /// Remplace l'écran du test en cours par son bilan.
  static Future<void> replace(BuildContext context, TestResult result) {
    return Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => TestResultScreen(result: result, justFinished: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = result;

    return Scaffold(
      body: SafitPage(
        header: SafitHeader(title: 'Résultats', showSettings: false),
        bottom: justFinished
            ? SafitButton(label: 'Terminer', onPressed: () => Navigator.of(context).pop())
            : null,
        children: [
          Row(
            children: [
              Icon(r.protocol.icon, size: 36, color: AppColors.accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.protocol.title, style: textTheme.titleLarge),
                    Text(formatDateTime(r.date), style: textTheme.bodySmall),
                  ],
                ),
              ),
              if (justFinished) const Icon(Icons.check_circle, color: AppColors.accent, size: 32),
            ],
          ),
          const SectionHeader(title: 'Bilan'),
          _Grid(tiles: _summaryTiles(r)),
          if (r.stages.isNotEmpty) ...[
            const SectionHeader(title: 'Par palier'),
            _StagesTable(r.stages),
          ],
          if (r.protocol == TestProtocol.subMaximal) ...[
            const SizedBox(height: AppSpacing.lg),
            const _Notice(
              'Le 2ᵉ palier et la pente fréquence cardiaque / puissance '
              '(indicateur de la VO2max) arriveront avec le ticket dédié.',
            ),
          ],
          const SectionHeader(title: 'Décélération'),
          _Grid(tiles: [
            _Tile(
              'Décélération',
              r.decelerationSlope?.toStringAsFixed(1),
              'tr/min par s',
            ),
            _Tile(
              'Régularité',
              r.decelerationR2 == null ? null : '${(r.decelerationR2! * 100).toStringAsFixed(0)} %',
              r.decelerationR2 == null ? '' : (r.decelerationR2! >= 0.95 ? 'linéaire' : 'à refaire'),
            ),
          ]),
          if (r.provisionalErgocycle) ...[
            const SizedBox(height: AppSpacing.lg),
            const _Notice(
              'Force et puissance calculées avec des paramètres d\'ergocycle provisoires '
              '(volant de 22 kg, dimensions à confirmer) : valeurs indicatives.',
              warning: true,
            ),
          ],
        ],
      ),
    );
  }

  /// Chiffres clés, selon le protocole.
  List<_Tile> _summaryTiles(TestResult r) {
    final common = [
      _Tile('Durée de l\'effort', formatDuration(r.duration), ''),
      _Tile('FC moyenne', r.avgHeartRateBpm?.toString(), 'bpm'),
    ];
    return switch (r.protocol) {
      TestProtocol.forceVelocity => [
          _Tile('Puissance max', r.peakPowerW?.round().toString(), 'W', highlight: true),
          _Tile('Cadence max', r.peakCadenceRpm?.round().toString(), 'rpm'),
          _Tile('Force de friction', r.frictionForceN?.toStringAsFixed(1), 'N'),
          ...common,
        ],
      TestProtocol.frictionCalibration => [
          _Tile('Force de friction', r.frictionForceN?.toStringAsFixed(1), 'N', highlight: true),
          _Tile('Cadence moyenne', r.avgCadenceRpm?.round().toString(), 'rpm'),
          ...common,
        ],
      TestProtocol.subMaximal || TestProtocol.incremental => [
          _Tile('Puissance moyenne', r.avgPowerW?.round().toString(), 'W', highlight: true),
          _Tile('Cadence moyenne', r.avgCadenceRpm?.round().toString(), 'rpm'),
          ...common,
          _Tile('FC max', r.maxHeartRateBpm?.toString(), 'bpm'),
          _Tile('Force de friction', r.frictionForceN?.toStringAsFixed(1), 'N'),
        ],
    };
  }
}

class _Tile {
  const _Tile(this.label, this.value, this.unit, {this.highlight = false});

  final String label;
  final String? value;
  final String unit;
  final bool highlight;
}

class _Grid extends StatelessWidget {
  const _Grid({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.8,
      children: [
        for (final tile in tiles)
          SafitCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tile.label, style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: tile.value ?? '--',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tile.highlight ? AppColors.accent : null,
                        ),
                      ),
                      if (tile.unit.isNotEmpty && tile.value != null)
                        TextSpan(text: ' ${tile.unit}', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StagesTable extends StatelessWidget {
  const _StagesTable(this.stages);

  final List<StageResult> stages;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget cell(String text, {bool header = false, TextAlign align = TextAlign.right}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            text,
            textAlign: align,
            style: header ? textTheme.bodySmall : textTheme.bodyMedium,
          ),
        );

    return SafitCard(
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.2)},
        children: [
          TableRow(children: [
            cell('Palier', header: true, align: TextAlign.left),
            cell('Cible', header: true),
            cell('Cadence', header: true),
            cell('FC', header: true),
            cell('Puiss.', header: true),
          ]),
          for (final s in stages)
            TableRow(children: [
              cell('${s.index + 1}', align: TextAlign.left),
              cell('${s.targetCadenceRpm.round()}'),
              cell(s.avgCadenceRpm?.round().toString() ?? '--'),
              cell(s.avgHeartRateBpm?.toString() ?? '--'),
              cell(s.avgPowerW == null ? '--' : '${s.avgPowerW!.round()} W'),
            ]),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.warning : AppColors.textSecondary;
    return SafitCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warning ? Icons.warning_amber_rounded : Icons.info_outline, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
