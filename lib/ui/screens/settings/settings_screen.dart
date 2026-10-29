import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';
import '../expert/camera_lab_screen.dart';
import '../sensors/heart_rate_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Ouvert par-dessus la coque : la barre du bas est masquée.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    void soon() => showComingSoon(context);

    return Scaffold(
      body: SafitPage(
        header: const SafitHeader(title: 'Réglages', showSettings: false),
        children: [
          _SettingsGroup(title: 'Capteurs', tiles: [
            _SettingsTile(
              Icons.photo_camera_outlined,
              'Caméra',
              subtitle: 'Zone de détection, test 240 fps',
              onTap: () => CameraLabScreen.open(context),
            ),
            _SettingsTile(
              Icons.favorite_border,
              'Polar H10',
              iconColor: AppColors.heartRate,
              onTap: () => HeartRateScreen.open(context),
            ),
          ]),
          _SettingsGroup(title: 'Ergocycle', tiles: [
            _SettingsTile(Icons.pedal_bike_outlined, 'Paramètres machine', onTap: soon),
          ]),
          _SettingsGroup(title: 'Application', tiles: [
            _SettingsTile(Icons.straighten, 'Unités', onTap: soon),
            _SettingsTile(Icons.school_outlined, 'Tutoriels', onTap: soon),
          ]),
          _SettingsGroup(title: 'Avancé', tiles: [
            _SettingsTile(
              Icons.lock_outline,
              'Mode expert',
              subtitle: 'Zone de détection, calibration, diagnostic',
              onTap: soon,
            ),
          ]),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.tiles});

  final String title;
  final List<_SettingsTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        SafitCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile(
    this.icon,
    this.title, {
    this.subtitle,
    this.iconColor = AppColors.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
