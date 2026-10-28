import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Cœur qui « bat » une fois à chaque nouvelle mesure reçue de la ceinture.
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({super.key, required this.bpm, this.size = 32});

  /// Dernière FC reçue ; chaque reconstruction avec une valeur déclenche un battement.
  final int? bpm;
  final double size;

  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final _scale = Tween(begin: 1.0, end: 1.25)
      .chain(CurveTween(curve: Curves.easeOut))
      .animate(_controller);

  @override
  void didUpdateWidget(BeatingHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bpm != null) {
      _controller.forward(from: 0).then((_) {
        if (mounted) _controller.reverse();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(Icons.favorite, color: AppColors.heartRate, size: widget.size),
    );
  }
}
