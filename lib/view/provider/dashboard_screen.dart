import 'package:flutter/material.dart';
import 'package:client/view/provider/jobs_screen.dart';
import 'package:client/view/message/message_screen.dart';
import 'package:client/view/profile/profile_screen.dart';
import 'package:client/view/provider/provider_profile_screen.dart';
import 'package:client/view/provider/wallet_screen.dart';
// Mirror the client home header (greeting + date + location chip)
import 'package:client/view/home/greet_header.dart';
import 'package:client/global/greet_user.dart';
import 'package:client/view/profile/address_screen.dart';

/// ProviderDashboardScreen
/// ------------------------
/// This is a presentational template for the Service Provider dashboard.
/// It follows the existing project theming (Material 3, seeded color scheme,
/// AnonymousPro headings as seen in other screens) and mirrors the provided
/// structure from the design image. Data shown here is mocked so the template
/// can be dropped in and later wired to live API/state.
///
/// Key sections implemented:
///  • Welcome header with avatar + bell icon
///  • Earnings card (period selector, amount, delta, progress to goal)
///  • Two stat tiles: Upcoming Jobs and Rating
///  • Next Job card with title, client, time, and location
///  • Manage list tiles (Analytics, Availability) leading to TODO routes
///  • Bottom navigation dedicated to provider: Dashboard, Jobs, Messages, Profile
///
/// NOTE: Meaningful comments are included to help future contributors wire this
/// up with real data and navigation. Keep the styling consistent with the rest
/// of the app (spacing, colors, typography).
class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  static const String route = '/provider/dashboard';

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _tabIndex = 0; // Bottom nav index

  // Mock data placeholders – replace with real store/API later.
  final String _name = 'John D.';
  // Selected/overridden location text from a location picker (optional)
  String? _selectedLocation; // When null or empty → show "Set location"

  final double _earnings = 450.75; // current period earnings
  final double _weeklyGoal = 600.0; // goal baseline
  final double _deltaPct = 0.15; // +15% vs previous period
  final int _upcomingJobs = 5;
  final double _rating = 4.9;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    // Derived presentation values
    final progress = (_earnings / _weeklyGoal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        // Host all provider tabs inside an IndexedStack so the bottom
        // navigation persists across tabs (Dashboard, Jobs, Messages, Profile).
        child: IndexedStack(
          index: _tabIndex,
          children: [
            // ---------------------- Dashboard tab (index 0) ----------------------
            Padding(
              padding: const EdgeInsets.all(15), // matches Home page padding
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------------------------------------------------------------
                    // Header (mirrors Client Home: greeting + date + Set location chip)
                    // -------------------------------------------------------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GreetingHeader(
                            name: _name,
                            greet: greetingMessage(), // time-based greeting (Good morning/afternoon/evening)
                            locationText: _selectedLocation,
                            onPressed: () {
                              // Reuse the same route the client uses to pick a location
                              // If not yet wired, this safely does nothing or will be added later.
                              Navigator.of(context).pushNamed('/location-picker');
                            },
                          ),
                        ),
                        // Actions on the right: notifications + profile avatar (to mirror client header)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                // TODO: Navigate to a notifications screen when available
                                // For now, we can show a simple placeholder.
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notifications coming soon')),
                                );
                              },
                              icon: const Icon(Icons.notifications_outlined),
                              tooltip: 'Notifications',
                            ),
                            const SizedBox(width: 6),
                            // Profile avatar button: switches to the Profile tab (index 4)
                            GestureDetector(
                              onTap: () {
                                setState(() => _tabIndex = 4);
                              },
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.primaryContainer,
                                foregroundColor: cs.onPrimaryContainer,
                                child: const Icon(Icons.person, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Earnings card
                    // -------------------------------------------------------------
                    _EarningsCard(
                      earnings: _earnings,
                      weeklyGoal: _weeklyGoal,
                      deltaPct: _deltaPct,
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Stats tiles (Upcoming jobs, Rating)
                    // -------------------------------------------------------------
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.event_available_outlined,
                            label: 'Upcoming Jobs',
                            value: '$_upcomingJobs',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.star_border_rounded,
                            label: 'Rating',
                            value: _rating.toStringAsFixed(1),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Next Job
                    // -------------------------------------------------------------
                    Text(
                      'Next Job',
                      style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _NextJobCard(
                      title: 'Plumbing Fix',
                      price: 75,
                      clientName: 'Jane Smith',
                      startsIn: 'in 30 mins',
                      address: '123 Main St, Anytown, USA',
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Manage section
                    // -------------------------------------------------------------
                    Text(
                      'Manage',
                      style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _ManageTile(
                      icon: Icons.query_stats_outlined,
                      title: 'Analytics',
                      onTap: () {
                        // Navigate to the provider analytics screen template
                        Navigator.of(context).pushNamed('/provider/analytics');
                      },
                    ),
                    const SizedBox(height: 10),
                    _ManageTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Payouts',
                      onTap: () {
                        // Navigate to provider payouts screen template
                        Navigator.of(context).pushNamed('/provider/payouts');
                      },
                    ),
                    const SizedBox(height: 10),
                    _ManageTile(
                      icon: Icons.event_note_outlined,
                      title: 'My Availability',
                      onTap: () {
                        Navigator.of(context).pushNamed('/provider/availability');
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // ------------------------- Jobs tab (index 1) -------------------------
            const ProviderJobsScreen(),

            // ------------------------- Wallet tab (index 2) -----------------------
            const ProviderWalletScreen(),

            // ----------------------- Messages tab (index 3) -----------------------
            const MessageScreen(),

            // ------------------------ Profile tab (index 4) -----------------------
            const ProviderProfileScreen(),
          ],
        ),
      ),

      // -----------------------------------------------------------------------
      // Provider bottom navigation
      // -----------------------------------------------------------------------
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          // Persist bottom navigation by switching tabs inside this screen
          // instead of pushing separate routes. This ensures the nav bar does
          // not disappear when opening Messages or other tabs.
          setState(() => _tabIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================================
// Widgets
// ----------------------------------------------------------------------------

/// Earnings card showing the current period earnings and progress to goal.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.earnings,
    required this.weeklyGoal,
    required this.deltaPct,
  });

  final double earnings;
  final double weeklyGoal;
  final double deltaPct; // positive or negative fraction (e.g., 0.15 = +15%)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;
    final progress = (earnings / weeklyGoal).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Earnings', style: text.titleMedium?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
                ),
                // Period selector – static for now
                Row(
                  children: [
                    Text('This Week', style: text.bodyMedium),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '' // SOFT hint of currency; explicit $ may be localized later
              '${earnings.toStringAsFixed(2)}',
              style: text.displaySmall?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  deltaPct >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: deltaPct >= 0 ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(deltaPct.abs() * 100).toStringAsFixed(0)}% vs last week',
                  style: text.bodyMedium?.copyWith(color: deltaPct >= 0 ? Colors.green : Colors.red),
                )
              ],
            ),
            const SizedBox(height: 12),
            // Progress to weekly goal
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text('Weekly goal: ' '${weeklyGoal.toStringAsFixed(0)}', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Simple tile for stat value + icon used in the 2-up grid.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: cs.primary),
            const SizedBox(height: 10),
            Text(label, style: text.titleMedium?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(value, style: text.headlineSmall?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Card showing details for the next scheduled job.
class _NextJobCard extends StatelessWidget {
  const _NextJobCard({
    required this.title,
    required this.price,
    required this.clientName,
    required this.startsIn,
    required this.address,
  });

  final String title;
  final num price;
  final String clientName;
  final String startsIn;
  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700),
                  ),
                ),
                Text('R' '${price.toString()}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(clientName, style: text.bodyLarge),
                Text(startsIn, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(address, style: text.bodyMedium),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

/// Simple list tile for the Manage section.
class _ManageTile extends StatelessWidget {
  const _ManageTile({required this.icon, required this.title, this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
