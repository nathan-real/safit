import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/ergocycle_parameters.dart';
import '../../../services/app_services.dart';
import '../../widgets/safit_button.dart';
import '../../widgets/safit_card.dart';
import '../../widgets/safit_header.dart';
import '../../widgets/safit_page.dart';

/// Caractéristiques de l'ergocycle, utilisées pour la force et la puissance.
/// Une fois enregistrées, les résultats ne sont plus marqués « provisoires ».
class ErgocycleScreen extends StatefulWidget {
  const ErgocycleScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ErgocycleScreen()),
    );
  }

  @override
  State<ErgocycleScreen> createState() => _ErgocycleScreenState();
}

class _ErgocycleScreenState extends State<ErgocycleScreen> {
  final _form = GlobalKey<FormState>();
  final _mass = TextEditingController();
  final _circumference = TextEditingController();
  final _ratio = TextEditingController();
  final _marks = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _fill(AppServices.of(context).ergocycle.parameters.value);
  }

  void _fill(ErgocycleParameters p) {
    _mass.text = _text(p.flywheelMassKg);
    _circumference.text = _text(p.flywheelCircumferenceM);
    _ratio.text = _text(p.flywheelTurnsPerPedalTurn);
    _marks.text = '${p.marksPerFlywheelTurn}';
  }

  static String _text(double v) {
    var s = v.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s.replaceAll('.', ',');
  }

  static double? _number(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_mass, _circumference, _ratio, _marks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final service = AppServices.of(context).ergocycle;
    await service.save(ErgocycleParameters(
      flywheelMassKg: _number(_mass.text)!,
      flywheelCircumferenceM: _number(_circumference.text)!,
      flywheelTurnsPerPedalTurn: _number(_ratio.text)!,
      marksPerFlywheelTurn: int.parse(_marks.text.trim()),
      provisional: false,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres de l\'ergocycle enregistrés')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final service = AppServices.of(context).ergocycle;
    await service.reset();
    setState(() => _fill(service.parameters.value));
  }

  String? Function(String?) _range(double min, double max) => (v) {
        final n = _number(v ?? '');
        if (n == null) return 'Obligatoire';
        if (n < min || n > max) return 'Entre ${_text(min)} et ${_text(max)}';
        return null;
      };

  @override
  Widget build(BuildContext context) {
    final service = AppServices.of(context).ergocycle;
    final textTheme = Theme.of(context).textTheme;
    final decimals = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    const gap = SizedBox(height: AppSpacing.md);

    Widget field(String key, TextEditingController c, String label, String help,
            String? Function(String?) validator,
            {bool integer = false}) =>
        TextFormField(
          key: Key(key),
          controller: c,
          decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 2),
          keyboardType: integer
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: integer ? [FilteringTextInputFormatter.digitsOnly] : decimals,
          validator: validator,
        );

    return Scaffold(
      body: SafitPage(
        header: const SafitHeader(title: 'Ergocycle', showSettings: false),
        bottom: SafitButton(label: 'Enregistrer', icon: Icons.check, onPressed: _save),
        children: [
          ValueListenableBuilder(
            valueListenable: service.parameters,
            builder: (_, p, _) => SafitCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    p.provisional ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: p.provisional ? AppColors.warning : AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      p.provisional
                          ? 'Valeurs provisoires : les forces et puissances sont indicatives. '
                              'Entrez les caractéristiques de l\'ergocycle du SMART.'
                          : 'Valeurs de l\'ergocycle enregistrées : elles servent à tous les calculs.',
                      style: textTheme.bodySmall?.copyWith(
                        color: p.provisional ? AppColors.warning : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _form,
            child: Column(
              children: [
                field('mass', _mass, 'Masse du volant (kg)',
                    'Masse qui ralentit pendant la décélération.', _range(1, 100)),
                gap,
                field('circumference', _circumference, 'Tour du volant (m)',
                    'Circonférence là où frotte la courroie.', _range(0.1, 5)),
                gap,
                field('ratio', _ratio, 'Tours de volant par tour de pédale',
                    'Rapport de transmission (ex. 3,7).', _range(0.5, 20)),
                gap,
                field('marks', _marks, 'Traits noirs sur le volant',
                    'Nombre de traits que compte la caméra par tour.', _range(1, 64),
                    integer: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SafitButton(
            label: 'Revenir aux valeurs provisoires',
            icon: Icons.restart_alt,
            variant: SafitButtonVariant.secondary,
            onPressed: _reset,
          ),
        ],
      ),
    );
  }
}
