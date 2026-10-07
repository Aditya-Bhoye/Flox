import 'package:flutter/material.dart';

/// The gradient + soft navy circle + vignette shared by the login and home
/// screens.
///
/// Everything here is a plain gradient (no blur filters) and sits behind a
/// RepaintBoundary, so it is drawn once and reused while content scrolls.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return RepaintBoundary(
      child: Stack(
        children: [
          // Base gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                colors: [
                  Color(0xFFE0EEFF), // Top: Whitish Blue
                  Color(0xFF0066FF), // Vibrant Blue
                  Color(0xFF001040), // Navy Blue
                  Color(0xFF7C4DFF), // Purple
                  Color(0xFFE0EEFF), // Bottom: Whitish Blue
                ],
              ),
            ),
          ),

          // Navy circle element. The extra stops give the soft edge a blur
          // filter used to produce, without the per-frame cost.
          OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: const Alignment(0.0, -0.5),
            child: Container(
              width: width * 2.0,
              height: width * 2.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF000A12),
                    Color(0xF2000A12),
                    Color(0xB3000A12),
                    Color(0x66000A12),
                    Color(0x1F000A12),
                    Color(0x00000A12),
                  ],
                  stops: [0.0, 0.25, 0.45, 0.65, 0.85, 1.0],
                ),
              ),
            ),
          ),

          // Vignette overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.5,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
