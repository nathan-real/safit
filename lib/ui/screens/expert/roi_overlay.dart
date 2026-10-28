import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Rectangle de la zone de détection, posé sur l'aperçu caméra.
/// On le déplace en le faisant glisser, on le redimensionne par la poignée
/// en bas à droite. [roi] est en coordonnées 0..1 de l'aperçu.
class RoiOverlay extends StatelessWidget {
  const RoiOverlay({super.key, required this.roi, required this.onChanged});

  final Rect roi;
  final ValueChanged<Rect> onChanged;

  static const _minSize = 0.05;
  static const _handle = 36.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final rect = Rect.fromLTWH(roi.left * w, roi.top * h, roi.width * w, roi.height * h);

        void move(Offset delta) {
          final left = (roi.left + delta.dx / w).clamp(0.0, 1 - roi.width);
          final top = (roi.top + delta.dy / h).clamp(0.0, 1 - roi.height);
          onChanged(Rect.fromLTWH(left, top, roi.width, roi.height));
        }

        void resize(Offset delta) {
          final width = (roi.width + delta.dx / w).clamp(_minSize, 1 - roi.left);
          final height = (roi.height + delta.dy / h).clamp(_minSize, 1 - roi.top);
          onChanged(Rect.fromLTWH(roi.left, roi.top, width, height));
        }

        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: _Draggable(
                onDrag: move,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              left: rect.right - _handle / 2,
              top: rect.bottom - _handle / 2,
              width: _handle,
              height: _handle,
              child: _Draggable(
                onDrag: resize,
                child: Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Zone qui « capture » le doigt dès qu'il la touche : la page ne défile pas
/// pendant qu'on déplace le rectangle (sinon la liste gagne le geste vertical).
class _Draggable extends StatelessWidget {
  const _Draggable({required this.onDrag, required this.child});

  final ValueChanged<Offset> onDrag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
          EagerGestureRecognizer.new,
          (_) {},
        ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerMove: (e) => onDrag(e.delta),
        child: child,
      ),
    );
  }
}
