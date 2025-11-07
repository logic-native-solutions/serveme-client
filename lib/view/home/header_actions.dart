import 'package:client/model/user_model.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart'; // Assuming kBrandFont is still here, or move it
import '../profile/profile_screen.dart';

/// Compact actions shown on the right of the header: notifications and avatar.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key, required this.user});

  /// The current user object.
  final UserModel user;

  String _initials(UserModel u) { // <--- CHANGE PARAMETER TYPE TO User
    final f = u.firstName.trim();
    final l = u.lastName.trim();
    if (f.isEmpty && l.isEmpty) return 'U';
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    return (f.isNotEmpty ? f[0] : l[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Access properties directly from the User object
    // Assuming 'avatarUrl' is a field in your User model.
    // If not, you might need to add it or adjust how you get it.
    final String avatarUrl = user.avatarUrl ?? ''; // <--- ACCESS FROM USER OBJECT
    // Add avatarUrl to your User model if it doesn't exist:
    // final String? avatarUrl;
    // And in fromJson: avatarUrl: json['avatarUrl'],

    final initials = _initials(user);
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).pushNamed('/notifications'),
          icon: const Icon(Icons.notifications_rounded, size: 24),
          padding: const EdgeInsets.all(12), // Ensure 44x44 tap target for accessibility
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen())),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isNotEmpty
                ? null
                : Text(
              initials,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFamily: kBrandFont,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
