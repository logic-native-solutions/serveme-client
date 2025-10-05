import 'package:flutter/material.dart';

/// RoleSelectorScreen
/// -------------------
/// Lightweight separator that lets you preview either the Client experience
/// (HomeShell) or the Provider experience (ProviderDashboardScreen).
///
/// Notes
/// - This is a non-auth, non-permission gate. It is purely a UX switch to help
///   you view both sides quickly during development.
/// - Colors, typography, and spacing follow the existing app theme.
/// - Remove this screen when real role-based routing is in place.
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  static const String route = '/choose-dashboard';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Choose Dashboard'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who are you previewing as?',
                style: text.headlineSmall?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              // Provider card
              _RoleCard(
                icon: Icons.work_outline,
                title: 'Provider',
                subtitle: 'See the provider dashboard and tools',
                color: cs.primary,
                onTap: () {
                  // Navigate to the provider dashboard template
                  Navigator.of(context).pushNamed('/provider/dashboard');
                },
              ),
              const SizedBox(height: 16),

              // Client card
              _RoleCard(
                icon: Icons.home_outlined,
                title: 'Client',
                subtitle: 'Return to the client home experience',
                color: cs.secondary,
                onTap: () {
                  // Pop any previous routes and go to the main client shell
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
                },
              ),

              const Spacer(),
              Text(
                'Tip: This screen is for development preview only. Actual role-based access will route automatically later.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small helper card used for each role entry.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleLarge?.copyWith(
                        fontFamily: 'AnonymousPro',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: text.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
