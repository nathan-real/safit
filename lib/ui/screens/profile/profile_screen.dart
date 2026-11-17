import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/athlete_profile.dart';
import '../../../services/app_services.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';
import '../../widgets/section_header.dart';
import '../account/profile_form.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Il faudra entrer votre mot de passe pour revenir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await AppServices.of(context).account.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = AppServices.of(context).account;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder(
      valueListenable: account.profile,
      builder: (context, profile, _) => SafitPage(
        header: const SafitHeader(title: 'Mon profil'),
        children: [
          if (profile != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    _initials(profile),
                    style: const TextStyle(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: Text(profile.fullName, style: textTheme.headlineSmall)),
              ],
            ),
            const SectionHeader(title: 'Informations'),
            SafitCard(
              child: Column(
                children: [
                  _InfoRow('Âge', profile.age == null ? null : '${profile.age} ans'),
                  _InfoRow('Poids', _unit(profile.weightKg, 'kg')),
                  _InfoRow('Taille', _unit(profile.heightCm, 'cm')),
                  _InfoRow('Sport', profile.sport),
                  _InfoRow('Objectif', profile.goal),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SafitButton(
              label: 'Modifier mon profil',
              icon: Icons.edit_outlined,
              variant: SafitButtonVariant.secondary,
              onPressed: () => EditProfileScreen.open(context, profile),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SafitButton(
            label: 'Se déconnecter',
            icon: Icons.logout,
            variant: SafitButtonVariant.secondary,
            onPressed: () => _logout(context),
          ),
        ],
      ),
    );
  }

  static String _initials(AthleteProfile p) =>
      [p.firstName, p.lastName].where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase()).join();

  static String? _unit(double? value, String unit) {
    if (value == null) return null;
    final n = value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
    return '$n $unit';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value ?? 'Non renseigné',
              style: value == null
                  ? textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)
                  : textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key, required this.profile});

  final AthleteProfile profile;

  static Future<void> open(BuildContext context, AthleteProfile profile) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EditProfileScreen(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = AppServices.of(context).account;
    return Scaffold(
      body: SafitPage(
        header: const SafitHeader(title: 'Modifier mon profil', showSettings: false),
        children: [
          ProfileForm(
            initial: profile,
            submitLabel: 'Enregistrer',
            onSubmit: (updated, _) async {
              await account.updateProfile(updated);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
