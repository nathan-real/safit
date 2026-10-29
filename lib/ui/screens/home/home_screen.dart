import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/camera_state.dart';
import '../../../models/heart_rate.dart';
import '../../../models/sensor_connection.dart';
import '../../../models/test_result.dart';
import '../../../services/app_services.dart';
import '../../shell/app_shell.dart';
import '../../widgets/coming_soon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/protocol_icon.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_list_tile.dart';
import '../../widgets/safit_logo.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_tile.dart';
import '../expert/camera_lab_screen.dart';
import '../sensors/heart_rate_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _recentCount = 2;

  late Future<List<TestResult>> _results;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _results = AppServices.of(context).results.listResults();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shell = AppShell.of(context);
    final services = AppServices.of(context);

    return SafitPage(
      header: const SafitHeader(titleWidget: SafitLogo()),
      children: [
        const SizedBox(height: AppSpacing.md),
        ValueListenableBuilder(
          valueListenable: services.profile.profile,
          builder: (_, profile, _) => Text(
            profile == null ? 'Bonjour 👋' : 'Bonjour ${profile.firstName} 👋',
            style: textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Prêt pour un nouveau test ?',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        SafitButton(
          label: 'Nouveau test',
          icon: Icons.play_arrow_rounded,
          onPressed: () => shell.goTo(AppTab.tests),
        ),
        const SectionHeader(title: 'État du système'),
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: services.heartRate.state,
                builder: (_, state, _) => _HeartRateTile(state),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: services.camera.state,
                builder: (_, state, _) => _CameraTile(state),
              ),
            ),
          ],
        ),
        SectionHeader(
          title: 'Tests récents',
          actionLabel: 'Voir tout',
          onAction: () => shell.goTo(AppTab.results),
        ),
        FutureBuilder(
          future: _results,
          builder: (context, snapshot) {
            final results = snapshot.data;
            if (results == null) return const SizedBox.shrink();
            if (results.isEmpty) {
              return const EmptyState(
                icon: Icons.history,
                title: 'Aucun test pour l\'instant',
                message: 'Vos derniers tests apparaîtront ici.',
              );
            }
            return Column(
              children: [
                for (final result in results.take(_recentCount)) ...[
                  _RecentTestTile(result),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HeartRateTile extends StatelessWidget {
  const _HeartRateTile(this.state);

  final HeartRateState state;

  @override
  Widget build(BuildContext context) {
    final (status, level) = switch (state.connection) {
      SensorConnection.connected => ('Connectée · ${state.bpm ?? '--'} bpm', StatusLevel.ready),
      SensorConnection.searching => ('Recherche…', StatusLevel.pending),
      SensorConnection.connecting => ('Connexion…', StatusLevel.pending),
      SensorConnection.disconnected => ('Non connectée', StatusLevel.off),
    };
    return StatusTile(
      icon: Icons.favorite_border,
      iconColor: AppColors.heartRate,
      label: 'Polar H10',
      status: status,
      level: level,
      onTap: () => HeartRateScreen.open(context),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile(this.state);

  final CameraState state;

  @override
  Widget build(BuildContext context) {
    final (status, level) = switch (state.status) {
      CameraStatus.ready when !state.highSpeed =>
        ('Prête · ${state.fps?.round() ?? '--'} fps seulement', StatusLevel.pending),
      CameraStatus.ready => ('Prête · ${state.fps?.round() ?? '--'} fps', StatusLevel.ready),
      CameraStatus.checking => ('Vérification…', StatusLevel.pending),
      CameraStatus.error => ('Indisponible', StatusLevel.off),
      CameraStatus.notConfigured => ('Zone non réglée', StatusLevel.off),
    };
    return StatusTile(
      icon: Icons.photo_camera_outlined,
      label: 'Caméra',
      status: status,
      level: level,
      onTap: () => CameraLabScreen.open(context),
    );
  }
}

class _RecentTestTile extends StatelessWidget {
  const _RecentTestTile(this.result);

  final TestResult result;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      if (result.avgPowerW != null) '${result.avgPowerW!.round()} W',
      if (result.peakPowerW != null) 'Pmax ${result.peakPowerW!.round()} W',
      if (result.avgHeartRateBpm != null) '${result.avgHeartRateBpm} bpm',
      if (result.avgPowerW == null && result.frictionForceN != null)
        '${result.frictionForceN!.toStringAsFixed(1)} N',
    ];
    return SafitListTile(
      icon: result.protocol.icon,
      title: result.protocol.title,
      subtitle: formatDateTime(result.date),
      footer: Text(metrics.join(' · ')),
      // Ouvrira le détail de la séance quand l'écran existera.
      onTap: () => showComingSoon(context),
    );
  }
}
