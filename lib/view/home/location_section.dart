import 'package:client/view/profile/address_screen.dart';
import 'package:flutter/material.dart';

/// A small, tappable chip that shows the user's location.
class LocationChip extends StatelessWidget {
  const LocationChip({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap ?? () async {
          // Default behavior: open AddressScreen. Prefer passing a custom
          // handler from parent when you need to capture the selected address.
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddressScreen()),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}