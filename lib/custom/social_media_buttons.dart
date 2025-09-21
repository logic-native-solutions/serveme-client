import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// SocialBox
/// A compact, accessible container for social media icons or other tappable
/// widgets.
///
/// Features
/// --------
/// • Enforces a minimum/maximum size (48–56px) for consistent touch targets.
/// • Provides rounded borders with splash support via [InkWell].
/// • Adds optional [semanticLabel] for screen readers.
/// ---------------------------------------------------------------------------
class SocialBox extends StatelessWidget {
  /// Callback invoked when the box is tapped.
  final VoidCallback onTap;

  /// The content to display inside the box (typically an [Icon]).
  final Widget child;

  /// Optional accessibility label announced by screen readers.
  final String? semanticLabel;

  const SocialBox({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });

  /// Builds the social box widget with constraints, semantics, and splash.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
        maxWidth: 56,
        maxHeight: 56,
      ),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: Colors.transparent, // gives InkWell a Material ancestor
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias, // keep splash within rounded border
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              // proper splash surface
              padding: const EdgeInsets.all(12),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}