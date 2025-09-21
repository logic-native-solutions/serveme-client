import 'package:flutter/material.dart';

/// Returns a time-of-day emoji: morning, afternoon, evening, night.
String _timeEmoji() {
  final h = DateTime.now().hour;
  if (h < 12) return '🌅';
  if (h < 17) return '☀️';
  if (h < 20) return '🌆';
  return '🌙';
}

/// Returns a short weekday name for [d] (Mon..Sun).
String _weekdayShort(DateTime d) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(d.weekday - 1).clamp(0, 6)];
}


/// Header that shows a prominent display name, and a subtle line with
/// a time-of-day emoji, friendly greeting, and short date.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.name, required this.greet});

  /// User's first name. If empty, a fallback "Welcome" is used.
  final String name;

  /// Friendly greeting text (e.g., "Good morning").
  final String greet;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final emoji = _timeEmoji();
    final dateLine = '${_weekdayShort(today)} ${today.day.toString().padLeft(2, '0')}';
    final displayName = name.isEmpty ? 'Welcome' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name as primary headline
        Text(
          displayName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontFamily: 'AnonymousPro',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        // Greeting + emoji + short date as a subtle line
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$emoji $greet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'AnonymousPro',
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
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}