import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'location_section.dart';

/// Returns a time-of-day emoji.
String _timeEmoji() {
  final h = DateTime.now().hour;
  if (h < 12) return '🌅';
  if (h < 17) return '☀️';
  if (h < 20) return '🌆';
  return '🌙';
}

/// Returns a short weekday name (Mon..Sun).
String _weekdayShort(DateTime d) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(d.weekday - 1).clamp(0, 6)];
}

String _shortenLocation(String? s) {
  if (s == null) return '';
  final text = s.trim();
  if (text.isEmpty) return '';
  // Prefer just street and city when comma-separated
  final parts = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final preferred = parts.length >= 2 ? '${parts[0]}, ${parts[1]}' : text;
  // Final safety: ellipsize if still too long
  return preferred.length > 36 ? preferred.substring(0, 35) + '…' : preferred;
}


/// Header with display name and a subtle line showing greeting + date.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    required this.greet,
    this.locationText,
    this.onPressed,
  });

  /// User's first name. If empty, a fallback "Welcome" is used.
  final String name;

  /// Friendly greeting text (e.g., "Good morning").
  final String greet;

  /// Optional resolved location text. If null or empty, a "Set location" chip
  /// is shown. If non-null, the value is displayed.
  final String? locationText;

  /// Optional tap handler for the location chip.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final emoji = _timeEmoji();
    final dateLine = '${_weekdayShort(today)} ${today.day.toString().padLeft(2, '0')}';
    final displayName = name.isEmpty ? 'Welcome' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$emoji $greet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: kBrandFont,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateLine,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: kBrandFont,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        // Name as primary headline
        Text(
          displayName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: kBrandFont,
              fontWeight: FontWeight.w700,
              fontSize: 28
          ),
        ),
        const SizedBox(height: 4),
        // Greeting + emoji + short date + location chip
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: LocationChip(
                label: (locationText == null || locationText!.trim().isEmpty)
                    ? 'Set location'
                    : _shortenLocation(locationText),
                onTap: onPressed,
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ],
    );
  }
}