import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/test_protocol.dart';
import '../../widgets/protocol_icon.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_list_tile.dart';
import '../../widgets/safit_page.dart';
import '../test_runner/preparation_flow.dart';

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafitPage(
      header: const SafitHeader(title: 'Choisir un test'),
      children: [
        for (final protocol in TestProtocol.values) ...[
          SafitListTile(
            icon: protocol.icon,
            title: protocol.title,
            subtitle: protocol.description,
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(
                  icon: Icons.flag_outlined,
                  text: protocol.objective,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: AppSpacing.xs),
                _InfoLine(icon: Icons.timer_outlined, text: protocol.duration),
              ],
            ),
            onTap: () => PreparationFlow.open(context, protocol),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Petite ligne « icône + texte » sous la description d'un test.
class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }
}
