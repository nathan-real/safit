import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Indicateur de progression : ● ─── ● ─── ○ ─── ○
/// Les étapes passées et l'étape en cours sont pleines.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.count, required this.current});

  final int count;

  /// Étape en cours, à partir de 0.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Étape ${current + 1} sur $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= current ? AppColors.accent : AppColors.border,
                ),
              ),
            _Dot(done: i < current, active: i == current),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.active});

  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = done || active;
    return Container(
      width: active ? 14 : 10,
      height: active ? 14 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.accent : Colors.transparent,
        border: Border.all(
          color: filled ? AppColors.accent : AppColors.textMuted,
          width: 2,
        ),
      ),
    );
  }
}
