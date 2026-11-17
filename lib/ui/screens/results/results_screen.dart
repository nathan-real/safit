import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/test_protocol.dart';
import '../../../models/test_result.dart';
import '../../../services/app_services.dart';
import '../../../services/storage/results_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/result_tile.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';

/// Historique de tous les tests, filtrable par type de test.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  ResultsService? _service;
  late Future<List<TestResult>> _results;

  /// Type de test affiché, ou null pour tous.
  TestProtocol? _filter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = AppServices.of(context).results;
    if (service == _service) return;
    _service?.changes.removeListener(_reload);
    _service = service..changes.addListener(_reload);
    _results = service.listResults();
  }

  @override
  void dispose() {
    _service?.changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _results = _service!.listResults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _results,
      builder: (context, snapshot) {
        final all = snapshot.data;
        final shown = [
          for (final r in all ?? const <TestResult>[])
            if (_filter == null || r.protocol == _filter) r,
        ];
        return SafitPage(
          header: const SafitHeader(title: 'Résultats'),
          children: [
            if (all != null && all.isEmpty)
              const EmptyState(
                icon: Icons.insights_outlined,
                title: 'Aucun résultat',
                message: 'Les résultats de vos tests seront enregistrés ici.',
              )
            else if (all != null) ...[
              _FilterBar(
                selected: _filter,
                onSelected: (p) => setState(() => _filter = p),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (shown.isEmpty)
                const EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Aucun test de ce type',
                )
              else
                for (final r in shown) ...[
                  ResultTile(r),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final TestProtocol? selected;
  final ValueChanged<TestProtocol?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, TestProtocol? value) {
      final isSelected = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.onAccent : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => onSelected(value),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Tous', null),
          for (final p in TestProtocol.values) chip(p.shortTitle, p),
        ],
      ),
    );
  }
}
