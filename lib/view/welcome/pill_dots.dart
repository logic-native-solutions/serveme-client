import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// IndicatorDots
///
/// A simple, dependency-free animated page indicator.
/// Displays:
///  • A row of small dots
///  • The active one stretches into a pill shape
///
/// Useful for onboarding carousels or any paged view.
/// ---------------------------------------------------------------------------
class IndicatorDots extends StatelessWidget {
  const IndicatorDots({
    super.key,
    required this.count,
    required this.index,
  });

  // -------------------------------------------------------------------------
  // Properties
  // -------------------------------------------------------------------------
  final int count;
  final int index;

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 22 : 8,
          decoration: BoxDecoration(
            color: isActive ? cs.primary : cs.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}