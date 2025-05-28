import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/canvas_mode_providers.dart';
import '../screens/canvas_mode_screen.dart';

class CanvasModeNavigator extends ConsumerWidget {
  final Widget child;

  const CanvasModeNavigator({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to canvas mode state changes
    ref.listen<CanvasModeState>(canvasModeProvider, (previous, next) {
      if (next.isActive && (previous?.isActive != true)) {
        // Navigate to canvas mode when activated
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CanvasModeScreen(
              initialCode: next.code,
              language: next.language,
            ),
            fullscreenDialog: true,
          ),
        ).then((_) {
          // Disable canvas mode when returning from the screen
          ref.read(canvasModeProvider.notifier).disableCanvasMode();
        });
      }
    });

    return child;
  }
}