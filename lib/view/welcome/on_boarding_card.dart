import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// OnboardCard
///
/// A presentation card used in the onboarding carousel.
/// Displays:
///  • A full-bleed background image
///  • A dark gradient overlay for readability
///  • Title and body text centered at the bottom
///
/// This widget is stateless and reusable for each onboarding slide.
/// ---------------------------------------------------------------------------
class OnboardCard extends StatelessWidget {
  const OnboardCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.text,
  });

  // -------------------------------------------------------------------------
  // Properties
  // -------------------------------------------------------------------------
  final String imagePath;
  final String title;
  final String text;

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final _ = Theme.of(context).colorScheme; // reserved for future theming

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // -----------------------------------------------------------------
          // Background image
          // -----------------------------------------------------------------
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),

          // -----------------------------------------------------------------
          // Gradient overlay (improves text contrast)
          // -----------------------------------------------------------------
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),

          // -----------------------------------------------------------------
          // Text content (title & body)
          // -----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 6,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black45,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
