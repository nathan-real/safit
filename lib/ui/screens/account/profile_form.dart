import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/athlete_profile.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/section_header.dart';

/// Formulaire du profil : utilisé à la création du compte et pour le modifier.
/// [withPassword] ajoute le choix du mot de passe (création du compte).
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    this.initial,
    this.withPassword = false,
    required this.submitLabel,
    required this.onSubmit,
  });

  final AthleteProfile? initial;
  final bool withPassword;
  final String submitLabel;

  /// Reçoit le profil saisi et le mot de passe (vide si [withPassword] est faux).
  final Future<void> Function(AthleteProfile profile, String password) onSubmit;

  /// Longueur minimale du mot de passe.
  static const minPasswordLength = 4;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.initial?.firstName);
  late final _lastName = TextEditingController(text: widget.initial?.lastName);
  late final _age = TextEditingController(text: _text(widget.initial?.age));
  late final _weight = TextEditingController(text: _text(widget.initial?.weightKg));
  late final _height = TextEditingController(text: _text(widget.initial?.heightCm));
  late final _sport = TextEditingController(text: widget.initial?.sport);
  late final _goal = TextEditingController(text: widget.initial?.goal);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  static String? _text(num? value) {
    if (value == null) return null;
    return value == value.roundToDouble() ? value.round().toString() : value.toString();
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _age, _weight, _height, _sport, _goal, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _optional(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  static double? _number(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final profile = AthleteProfile(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      age: int.tryParse(_age.text.trim()),
      weightKg: _number(_weight),
      heightCm: _number(_height),
      sport: _optional(_sport),
      goal: _optional(_goal),
    );
    try {
      await widget.onSubmit(profile, _password.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null;

  /// Champ numérique facultatif, vérifié dans une plage raisonnable.
  String? Function(String?) _range(double min, double max) => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        final n = double.tryParse(t.replaceAll(',', '.'));
        if (n == null || n < min || n > max) return 'Entre ${min.round()} et ${max.round()}';
        return null;
      };

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.md);
    final decimals = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('firstName'),
            controller: _firstName,
            decoration: const InputDecoration(labelText: 'Prénom *'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          gap,
          TextFormField(
            key: const Key('lastName'),
            controller: _lastName,
            decoration: const InputDecoration(labelText: 'Nom *'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          if (widget.withPassword) ...[
            gap,
            TextFormField(
              key: const Key('password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe *'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v ?? '').length < ProfileForm.minPasswordLength
                  ? 'Au moins ${ProfileForm.minPasswordLength} caractères'
                  : null,
            ),
            gap,
            TextFormField(
              key: const Key('confirm'),
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmer le mot de passe *'),
              textInputAction: TextInputAction.next,
              validator: (v) => v != _password.text ? 'Les mots de passe sont différents' : null,
            ),
          ],
          const SectionHeader(title: 'Facultatif'),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('age'),
                  controller: _age,
                  decoration: const InputDecoration(labelText: 'Âge'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _range(5, 120),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  key: const Key('weight'),
                  controller: _weight,
                  decoration: const InputDecoration(labelText: 'Poids (kg)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimals,
                  validator: _range(20, 250),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  key: const Key('height'),
                  controller: _height,
                  decoration: const InputDecoration(labelText: 'Taille (cm)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimals,
                  validator: _range(100, 250),
                ),
              ),
            ],
          ),
          gap,
          TextFormField(
            key: const Key('sport'),
            controller: _sport,
            decoration: const InputDecoration(labelText: 'Sport pratiqué'),
            textInputAction: TextInputAction.next,
          ),
          gap,
          TextFormField(
            key: const Key('goal'),
            controller: _goal,
            decoration: const InputDecoration(labelText: 'Objectif'),
          ),
          const SizedBox(height: AppSpacing.xl),
          SafitButton(
            label: widget.submitLabel,
            icon: Icons.check,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
