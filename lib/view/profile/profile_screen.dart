import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: _ProfileScreen(),
      ),
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  // TODO: Wire these to your real user store / API.
  final String? _profileImageUrl = null; // e.g. https://... or null
  final String _fullName = 'Phumudzo Maphari';
  final String _email = 'its.vinnie27@gmail.com';
  final String _phone = '5852451547';
  final String _memberSince = '2025';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Profile',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar with initials fallback
          CircleAvatar(
            radius: 56,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
            backgroundImage:
                _profileImageUrl != null ? NetworkImage(_profileImageUrl) : null,
            child: _profileImageUrl == null
                ? Text(
                    _initialsFromName(_fullName),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),

          // Name & Member since
          Text(
            _fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Member since $_memberSince',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),

          // Edit profile button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                // TODO: navigate to edit profile
              },
              child: const Text('Edit Profile'),
            ),
          ),

          const SizedBox(height: 24),

          // Contacts section
          const _SectionTitle(title: 'Contacts'),
          _InfoTile(
            icon: Icons.email_rounded,
            label: 'Email',
            value: _email,
            onTap: () {
              // TODO: copy or open mail
            },
          ),
          _InfoTile(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: _phone,
            onTap: () {
              // TODO: call or copy
            },
          ),

          const SizedBox(height: 24),

          // Settings section
          const _SectionTitle(title: 'Settings'),
          _InfoTile(
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          _InfoTile(
            icon: Icons.privacy_tip_rounded,
            label: 'Privacy',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          _InfoTile(
            icon: Icons.help_rounded,
            label: 'Help Center',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

String _initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r"\s+"));
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: value != null
          ? Text(
              value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
