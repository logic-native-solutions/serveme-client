import 'package:client/auth/api_client.dart';
import 'package:client/auth/role_store.dart';
import 'package:client/view/kyc/kyc_flow.dart';
import 'package:flutter/material.dart';

import '../profile/edit_profile.dart';
import '../profile/notification_screen.dart';
import '../profile/privacy_screen.dart';
import '../profile/help_screen.dart';
import '../home/current_user.dart';

/// ProviderProfileScreen
/// ----------------------
/// A provider-focused profile UI that highlights professional identity,
/// verification, service details, ratings, and earnings. This is a
/// presentational template following the app's existing theme (Material 3)
/// and typography (AnonymousPro for major headings). All data here is mocked
/// with clear TODOs indicating where to connect your backend.
///
/// Sections
///  1) Header: avatar, name, member since, role tag, rating summary, Edit Profile
///  2) Identity: KYC (Arya flow), Background Check (future), Approval Status
///  3) Service Information: category, skills (chips), radius, availability, pricing, experience
///  4) Performance: average rating, jobs completed, Reviews link (placeholder)
///  5) Earnings & Payouts: wallet balance, Withdraw, transaction summary, payout method masked
///  6) Account Settings: notifications, privacy, help, switch dashboard, logout
class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  // ---------------------------------------------------------------------------
  // Mock data — Replace with your provider store / API
  // ---------------------------------------------------------------------------
  final int _memberSinceYear = 2022; // TODO: Fetch from backend
  final double _avgRating = 4.8; // TODO: Fetch from backend
  final int _jobsCompleted = 120; // TODO: Fetch from backend
  final String _primaryCategory = 'Plumber'; // TODO: Fetch from backend
  final List<String> _skills = const ['Leak repair', 'Pipe fitting', 'Drain cleaning', 'Water heaters', 'Emergency callout']; // TODO
  final String _serviceRadius = '15 km around Pretoria'; // TODO
  final String _availability = 'Mon–Fri • 09:00–17:00'; // TODO
  final String _pricing = 'R250/hr'; // TODO
  final String _experience = '3 years professional experience'; // TODO
  final double _walletBalance = 1250.00; // TODO
  final String _payoutAccountMasked = 'Bank • **** 1234'; // TODO

  @override
  void initState() {
    super.initState();
    // Load the current user so we can render real profile data for the provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CurrentUserStore.I.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================ Header ==============================
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
              Card(
                elevation: 0,
                color: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  // Removed side border to mirror client profile (no visible container borders)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar and Name with verification badge driven by CurrentUserStore
                      AnimatedBuilder(
                        animation: CurrentUserStore.I,
                        builder: (context, _) {
                          final u = CurrentUserStore.I.user;
                          final fullName = u == null
                              ? ''
                              : [u.firstName, u.lastName].where((s) => (s).trim().isNotEmpty).join(' ');
                          final avatarUrl = u?.avatarUrl;
                          final isVerified = u?.verified == true;
                          return Column(
                            children: [
                              CircleAvatar(
                                radius: 80,
                                backgroundColor: cs.primaryContainer,
                                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Icon(Icons.person, color: cs.onPrimaryContainer, size: 64)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      fullName.isEmpty ? '—' : fullName,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.headlineSmall?.copyWith(
                                        fontFamily: 'AnonymousPro',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isVerified) Icon(Icons.verified, size: 18, color: cs.primary),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 6),

                      // Role tag under the name
                      Center(child: _Tag(label: 'Provider', color: cs.primary)),

                      const SizedBox(height: 6),

                      // Member since under the role
                      Text(
                        'Member since $_memberSinceYear',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),

                      const SizedBox(height: 8),

                      // Ratings and Jobs Completed
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_avgRating.toStringAsFixed(1)} | $_jobsCompleted Jobs Completed',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Edit button structure matches the client profile (full-width primary)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfile()));
                          },
                          child: const Text('Edit Profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============================ Identity ============================
              _SectionHeader(title: 'Identity'),
              _SectionCard(children: [
                // Identity Verification (same Arya KYC flow)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: _IconTile(bg: cs.surfaceContainerHighest, icon: Icons.verified_user_outlined),
                  title: const Text('Identity Verification'),
                  subtitle: Text('Complete KYC to keep your account compliant'),
                  trailing: AnimatedBuilder(
                    animation: CurrentUserStore.I,
                    builder: (context, _) {
                      final isVerified = CurrentUserStore.I.user?.verified == true;
                      return _StatusPill(label: isVerified ? 'Verified' : 'Verify', positive: isVerified);
                    },
                  ),
                  onTap: () async {
                    // Wire to Arya KYC flow (shared)
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KycFlowScreen(
                          expectedName: () {
                            final u = CurrentUserStore.I.user;
                            if (u == null) return '';
                            return [u.firstName, u.lastName].where((s) => s.trim().isNotEmpty).join(' ');
                          }(),
                          expectedDob: DateTime(2000, 1, 1),
                          profileAvatarAsset: 'assets/images/avatar.png',
                          expectedIdNumber: '0000000000000',
                          expectedGender: 'Unspecified',
                        ),
                      ),
                    );
                    if (!context.mounted) return;
                    // TODO: Refresh KYC status from backend
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KYC flow finished (mock)')));
                  },
                ),
                Divider(height: 1, color: cs.outlineVariant),
                // Background Check (future)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: _IconTile(bg: cs.surfaceContainerHighest, icon: Icons.policy_outlined),
                  title: const Text('Background Check'),
                  subtitle: const Text('Optional • Not required for launch'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Background check coming soon')));
                  },
                ),
                Divider(height: 1, color: cs.outlineVariant),
                // Profile Approval Status
                AnimatedBuilder(
                  animation: CurrentUserStore.I,
                  builder: (context, _) {
                    final isVerified = CurrentUserStore.I.user?.verified == true;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: _IconTile(bg: cs.surfaceContainerHighest, icon: Icons.check_circle_outline),
                      title: const Text('Profile Approval Status'),
                      subtitle: Text(isVerified ? 'Verified' : 'Pending'),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 20),

              // ======================= Service Information ======================
              _SectionHeader(title: 'Service Information'),
              _SectionCard(children: [
                _InfoRow(label: 'Primary Category', value: _primaryCategory),
                Divider(height: 1, color: cs.outlineVariant),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Skills', style: text.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _skills.take(5).map((s) => _Chip(tag: s)).toList(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                _InfoRow(label: 'Service Radius', value: _serviceRadius),
                Divider(height: 1, color: cs.outlineVariant),
                _InfoRow(label: 'Availability', value: _availability, trailing: TextButton(onPressed: () {
                  Navigator.of(context).pushNamed('/provider/availability');
                }, child: const Text('Edit'))),
                Divider(height: 1, color: cs.outlineVariant),
                _InfoRow(label: 'Pricing', value: _pricing),
                Divider(height: 1, color: cs.outlineVariant),
                _InfoRow(label: 'Experience', value: _experience),
              ]),

              const SizedBox(height: 20),

              // =========================== Performance ==========================
              _SectionHeader(title: 'Performance'),
              _SectionCard(children: [
                ListTile(
                  leading: const Icon(Icons.star_rate_rounded, color: Colors.amber),
                  title: Text('Average Rating'),
                  trailing: Text(_avgRating.toStringAsFixed(1), style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: const Text('Jobs Completed'),
                  trailing: Text('$_jobsCompleted', style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.reviews_outlined),
                  title: const Text('Reviews'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to reviews screen
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reviews screen placeholder')));
                  },
                ),
              ]),

              const SizedBox(height: 20),

              // ========================= Account Settings =======================
              _SectionHeader(title: 'Account Settings'),
              _SectionCard(children: [
                ListTile(
                  leading: const Icon(Icons.notifications_rounded),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen())),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded),
                  title: const Text('Privacy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyScreen())),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.help_rounded),
                  title: const Text('Help Center'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpScreen())),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    // Perform a clean logout, clear role cache, and take user to Login.
                    await ApiClient.logout();
                    RoleStore.clear();
                    // Also clear any cached current-user profile so the next session starts clean.
                    try { CurrentUserStore.I.clear(); } catch (_) {}
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                    }
                  },
                ),
              ]),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: text.titleLarge?.copyWith(
          fontFamily: 'AnonymousPro',
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.bg, required this.icon});
  final Color bg; final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.positive = true});
  final String label; final bool positive;
  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label; final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.tag});
  final String tag;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(tag, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});
  final String label; final String value; final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      title: Text(label, style: text.titleMedium),
      subtitle: Text(value, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      trailing: trailing,
    );
  }
}
