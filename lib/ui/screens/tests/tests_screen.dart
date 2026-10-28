import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/test_protocol.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/protocol_icon.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_list_tile.dart';
import '../../widgets/safit_page.dart';

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
            footer: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Text(protocol.duration),
              ],
            ),
            onTap: () => showComingSoon(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
