import 'package:flutter/material.dart';

import 'home_screen.dart';

/// Compact actions shown on the right of the header: notifications and avatar.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key, required this.user});

  /// The current user map (expects keys like firstName, lastName, avatarUrl).
  final Map<String, dynamic>? user;

  String _initials(Map<String, dynamic>? u) {
    final f = (u?['firstName'] ?? '').toString().trim();
    final l = (u?['lastName'] ?? '').toString().trim();
    if (f.isEmpty && l.isEmpty) return 'U';
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    return (f.isNotEmpty ? f[0] : l[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = (user?['avatarUrl'] ?? '').toString().trim();
    final initials = _initials(user);
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).pushNamed('/notifications'),
          icon: const Icon(Icons.notifications_outlined, size: 26),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/profile'),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            backgroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
            child: avatarUrl.isEmpty
                ? Text(
              initials,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFamily: kBrandFont,
                fontWeight: FontWeight.w800,
              ),
            )
                : null,
          ),
        ),
      ],
    );
  }
}