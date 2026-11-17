import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../services/app_services.dart';
import '../../../services/storage/account_service.dart';
import '../../shell/app_shell.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_logo.dart';
import 'profile_form.dart';

/// Premier écran de l'app : création du compte, connexion, ou l'app elle-même.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AppServices.of(context).account;
    return ValueListenableBuilder(
      valueListenable: account.status,
      builder: (_, status, _) => switch (status) {
        AccountStatus.loading => const Scaffold(body: Center(child: SafitLogo())),
        AccountStatus.noAccount => const CreateAccountScreen(),
        AccountStatus.loggedOut => const LoginScreen(),
        AccountStatus.loggedIn => const AppShell(),
      },
    );
  }
}

/// Mise en page commune : logo, titre, texte d'explication, puis le contenu.
class _AuthLayout extends StatelessWidget {
  const _AuthLayout({required this.title, required this.message, required this.child});

  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                const SizedBox(height: AppSpacing.xl),
                const SafitLogo(),
                const SizedBox(height: AppSpacing.xxl),
                Text(title, style: textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AppServices.of(context).account;
    return _AuthLayout(
      title: 'Créer mon profil',
      message: 'Vos informations restent sur ce téléphone. '
          'Le mot de passe protège l\'accès à vos résultats.',
      child: ProfileForm(
        withPassword: true,
        submitLabel: 'Créer mon profil',
        onSubmit: account.create,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _busy = true);
    final ok = await AppServices.of(context).account.login(_password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Mot de passe incorrect';
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = AppServices.of(context).account;
    return ValueListenableBuilder(
      valueListenable: account.profile,
      builder: (_, profile, _) => _AuthLayout(
        title: profile == null ? 'Connexion' : 'Bonjour ${profile.firstName}',
        message: 'Entrez votre mot de passe pour accéder à l\'application.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('loginPassword'),
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Mot de passe', errorText: _error),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: AppSpacing.xl),
            SafitButton(
              label: 'Se connecter',
              icon: Icons.login,
              onPressed: _busy ? null : _login,
            ),
          ],
        ),
      ),
    );
  }
}
