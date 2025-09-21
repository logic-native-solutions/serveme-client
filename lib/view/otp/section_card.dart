import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// SectionCard
///
/// A reusable card used in OTP and verification flows. Displays:
///  • Title and optional subtitle (with “Change” link)
///  • An input field
///  • Primary and secondary actions (buttons)
///
/// This widget keeps layout consistent across email/SMS verification sections.
/// ---------------------------------------------------------------------------
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.input,
    required this.primaryActionLabel,
    required this.primaryActionEnabled,
    required this.onPrimaryAction,
    required this.secondaryActionLabel,
    required this.secondaryActionEnabled,
    required this.onSecondaryAction,
    this.onEdit,
  });

  // -------------------------------------------------------------------------
  // Properties
  // -------------------------------------------------------------------------
  final String title;
  final String subtitle;
  final Widget input;

  final String primaryActionLabel;
  final bool primaryActionEnabled;
  final VoidCallback onPrimaryAction;

  final String secondaryActionLabel;
  final bool secondaryActionEnabled;
  final VoidCallback onSecondaryAction;

  /// Optional callback to edit the subtitle value (e.g., “Change” link).
  final VoidCallback? onEdit;

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      // Uses the global [cardTheme]
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle + optional “Change” button
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Change'),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Input field
            input,

            const SizedBox(height: 12),

            // Buttons row
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 48),
                  ),
                  onPressed: primaryActionEnabled ? onPrimaryAction : null,
                  child: Text(primaryActionLabel),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                  ),
                  onPressed:
                      secondaryActionEnabled ? onSecondaryAction : null,
                  child: Text(secondaryActionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}