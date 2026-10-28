import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/heart_rate.dart';
import '../../models/sensor_connection.dart';
import '../../services/app_services.dart';
import 'beating_heart.dart';
import 'check_row.dart';
import 'safit_button.dart';
import 'safit_card.dart';

/// Bloc « ceinture cardiaque » selon l'état de connexion :
/// FC en direct si connectée, sinon recherche et liste des ceintures.
/// Utilisé dans le parcours de préparation et sur l'écran Polar H10.
class HeartRatePanel extends StatelessWidget {
  const HeartRatePanel({super.key, this.allowDisconnect = false});

  final bool allowDisconnect;

  @override
  Widget build(BuildContext context) {
    final heartRate = AppServices.of(context).heartRate;

    return ValueListenableBuilder(
      valueListenable: heartRate.state,
      builder: (context, state, _) => switch (state.connection) {
        SensorConnection.connected => _ConnectedBelt(
            state: state,
            onDisconnect: allowDisconnect ? heartRate.disconnect : null,
          ),
        SensorConnection.searching => const _Progress('Recherche de ceintures…'),
        SensorConnection.connecting => const _Progress('Connexion…'),
        SensorConnection.disconnected => _BeltSearch(
            devices: state.foundDevices,
            onScan: heartRate.scan,
            onConnect: heartRate.connect,
          ),
      },
    );
  }
}

class _ConnectedBelt extends StatelessWidget {
  const _ConnectedBelt({required this.state, this.onDisconnect});

  final HeartRateState state;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafitCard(
          child: Column(
            children: [
              CheckRow(
                label: state.device?.name ?? 'Polar H10',
                state: CheckState.ok,
                detail: 'Connectée',
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BeatingHeart(bpm: state.bpm),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${state.bpm ?? '--'}',
                    style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('bpm', style: textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Fréquence cardiaque en direct', style: textTheme.bodySmall),
              if (state.batteryPercent != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _batteryIcon(state.batteryPercent!),
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Batterie ${state.batteryPercent} %', style: textTheme.bodySmall),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (onDisconnect != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SafitButton(
            label: 'Déconnecter',
            icon: Icons.bluetooth_disabled,
            variant: SafitButtonVariant.secondary,
            onPressed: onDisconnect,
          ),
        ],
      ],
    );
  }

  static IconData _batteryIcon(int percent) => switch (percent) {
        >= 80 => Icons.battery_full,
        >= 50 => Icons.battery_5_bar,
        >= 20 => Icons.battery_3_bar,
        _ => Icons.battery_alert,
      };
}

class _BeltSearch extends StatelessWidget {
  const _BeltSearch({
    required this.devices,
    required this.onScan,
    required this.onConnect,
  });

  final List<HeartRateDevice> devices;
  final VoidCallback onScan;
  final void Function(HeartRateDevice) onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          devices.isEmpty
              ? 'Mettez la ceinture, puis lancez la recherche.'
              : 'Touchez votre ceinture pour vous connecter.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final device in devices) ...[
          SafitCard(
            onTap: () => onConnect(device),
            child: Row(
              children: [
                const Icon(Icons.favorite_border, color: AppColors.heartRate),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(device.name)),
                const Text('Connecter', style: TextStyle(color: AppColors.accent)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SafitButton(
          label: 'Rechercher',
          icon: Icons.bluetooth_searching,
          variant: SafitButtonVariant.secondary,
          onPressed: onScan,
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
