import 'package:client/auth/api_client.dart';
import 'package:client/auth/role_store.dart';
import 'package:client/view/kyc/kyc_flow.dart';
import 'package:client/view/profile/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard for tap-to-copy

import 'package:client/model/user_model.dart';
// ... keep your other imports
import 'package:client/service/referral_service.dart';

import '../../custom/loader.dart';
import '../home/current_user.dart';
import 'address_screen.dart';
import 'edit_profile.dart';
import 'help_screen.dart';
import 'notification_screen.dart';
import '../home/location_store.dart';

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

class UserField extends StatelessWidget {
  final String fieldKey;
  final String fallback;
  final TextStyle style;

  const UserField({
    super.key,
    required this.fieldKey,
    this.fallback = 'Unknown',
    this.style = const TextStyle(fontSize: 14),
  });

  String? _valueForKey(UserModel u, String key) {
    switch (key) {
      case 'id':
        return u.id;
      case 'firstName':
        return u.firstName;
      case 'lastName':
        return u.lastName;
      case 'email':
        return u.email;
      case 'phone_number':
        return u.phoneNumber;
      case 'city':
        return u.city;
      case 'country':
        return u.country;
      case 'avatarUrl':
        return u.avatarUrl;
      case 'locationText':
      case 'location':
        return u.locationText;
      case 'fullName':
      case 'name':
        final parts = [u.firstName, u.lastName].where((s) => s.trim().isNotEmpty);
        return parts.join(' ');
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurrentUserStore.I,
      builder: (context, _) {
        final user = CurrentUserStore.I.user;

        if (CurrentUserStore.I.isLoading && user == null) {
          return appLoader;
        }

        final value = user == null ? null : _valueForKey(user, fieldKey);

        if (value == null || value.trim().isEmpty) {
          return Text(fallback, style: style);
        }

        return Text(value, style: style);
      },
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  // Tap-to-copy helper: copies non-empty value and shows themed SnackBar feedback.
  void _copyToClipboard(BuildContext context, String label, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $label to copy')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }
  @override
  void initState() {
    super.initState();
    // Defer to next frame so notifyListeners() doesn’t fire during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CurrentUserStore.I.load();
    });
  }

  String _fullNameString() {
    final u = CurrentUserStore.I.user;
    final f = u?.firstName;
    final l = u?.lastName;
    final name = ('$f $l');
    return name.isNotEmpty ? name : 'Unknown';
  }

  String? selectedAddress;

  String _addressLabel() {
    // Prefer a recently selected address
    if (selectedAddress != null && selectedAddress!.isNotEmpty) {
      return selectedAddress!;
    }
    // // Fall back to whatever might exist on the current user object
    // final u = CurrentUserStore.I.user;
    // final fromUser = ((u?.address ?? u?['addressLine'] ?? u?['street'] ?? '')).toString();
    // if (fromUser.isNotEmpty) return fromUser;
    return 'Add address';
    }

  final String? _profileImageUrl = null; // e.g. https://... or null
  final String _memberSince = '2025';

  //--- KYC helpers: pull known fields from the current user for comparisons
  String? _expectedIdNumber() {
    final u = CurrentUserStore.I.user;
    final id = u?.id.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  }
  //
  String? _expectedGender() {
    final u = CurrentUserStore.I.user;
    // Accept "M", "F" or "Male", "Female" — normalize to single letter
    final g = u?.gender.toString();
    if (g == null || g.isEmpty) return null;
    return g.substring(0, 1).toUpperCase();
  }

  /// KYC status from server. Fallback to 'pending' when not present.
  String _kycStatus() {
    final u = CurrentUserStore.I.user;
    final s = (u?.verified ?? 'pending').toString().toLowerCase();
    // normalize a few variants
    if (s == 'true' ) return 'verified';
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          // ----------------- Page Title -----------------
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

          // ----------------- Identity Header -----------------
          // Avatar + Name + Member since
          // Use ClipOval + Image.asset with BoxFit.contain to avoid zoomed/cropped avatar
          CircleAvatar(
            radius: 80,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
            child: ClipOval(
              child: Image.asset(
                'assets/images/avatar.png',
                fit: BoxFit.contain, // do not crop; keep full image visible inside the circle
                width: 160,
                height: 160,
              ),
            ),
          ),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: CurrentUserStore.I,
            builder: (context, _) {
              final isVerified = _kycStatus() == 'verified';
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _fullNameString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVerified) const SizedBox(width: 8),
                  if (isVerified) const _VerifiedBadge(),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          // Role badge to mirror Provider's role tag; keeps app consistent
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.35)),
              ),
              child: Text(
                'Client',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Member since $_memberSince',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),

          // ----------------- Edit Profile Button -----------------
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfile()));
              },
              child: const Text('Edit Profile'),
            ),
          ),

          const SizedBox(height: 20),

          // ======================= Identity Section =======================
          const _SectionHeader(title: 'Identity'),
          // A single, focused tile for KYC that shows status and explains action.
          _KycTile(
            status: _kycStatus(),
            onTap: () async {
              final _ = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => KycFlowScreen(
                    expectedName: _fullNameString(),
                    expectedDob:  DateTime(2000, 1, 1),
                    profileAvatarAsset: 'assets/images/avatar.png',
                    expectedIdNumber: _expectedIdNumber(),
                    expectedGender: _expectedGender(),
                  ),
                ),
              );
              if (!context.mounted) return;
              // Reload user to get updated kycStatus and re-build UI
              CurrentUserStore.I.load();
              setState(() {});
            },
          ),

          const SizedBox(height: 24),

          // ======================= Contact Information =======================
          const _SectionHeader(title: 'Contact Information'),
          _SectionCard(
            children: [
              // Email row — tap to copy email to clipboard
              InfoTile(
                icon: Icons.email_rounded,
                label: 'Email',
                value: UserField(fieldKey: 'email', style: subtitleStyle ?? const TextStyle(fontSize: 14)),
                onTap: () {
                  final email = CurrentUserStore.I.user?.email; // pull latest value
                  _copyToClipboard(context, 'Email', email);
                },
              ),
              // Phone row — tap to copy phone number to clipboard
              InfoTile(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: UserField(fieldKey: 'phone_number', style: subtitleStyle ?? const TextStyle(fontSize: 14)),
                onTap: () {
                  final phone = CurrentUserStore.I.user?.phoneNumber; // pull latest value
                  _copyToClipboard(context, 'Phone', phone);
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ======================= Addresses =======================
          const _SectionHeader(title: 'Addresses'),
          _SectionCard(
            children: [
              // Primary address row — shows address as the value
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_on_rounded, color: theme.colorScheme.onSurfaceVariant),
                ),
                title: const Text('Primary Address'),
                subtitle: Text(
                  _addressLabel(),
                  style: subtitleStyle,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddressScreen()),
                  );
                  if (result is Map && result['description'] is String) {
                    final picked = (result['description'] as String).trim();
                    setState(() {
                      selectedAddress = picked;
                    });
                    // Update shared LocationStore so Home/Provider headers reflect this Primary Address
                    LocationStore.I.address = picked;
                  }
                },
              ),
              // Optional: Add Address action
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                title: const Text('Add Address'),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddressScreen()),
                  );
                  if (result is Map && result['description'] is String) {
                    final picked = (result['description'] as String).trim();
                    setState(() {
                      selectedAddress = picked;
                    });
                    LocationStore.I.address = picked;
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ======================= Rewards & Referrals =======================
          const _SectionHeader(title: 'Rewards & Referrals'),
          _SectionCard(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.secondary),
                ),
                title: const Text('Invite a Friend'),
                subtitle: Text('Share ServeMe and you both get R50 credit', style: subtitleStyle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // Invite a Friend: opens native share sheet with referral link.
                  // Uses ReferralService to build a user-scoped link.
                  // Dark-mode safe (native sheet) and aligned with app theme.
                  final svc = await Future.value(null); // no-op to keep analyzer happy for async
                  // ignore: unused_local_variable
                  final _ = svc; // placeholder
                  try {
                    // Lazy import to top of file ensures minimal coupling.
                    // See: lib/service/referral_service.dart
                    // ignore: use_build_context_synchronously
                    await ReferralService.shareInvite(context);
                  } catch (_) {}
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ======================= Account Settings =======================
          const _SectionHeader(title: 'Account Settings'),
          _SectionCard(
            children: [
              InfoTile(
                icon: Icons.notifications_rounded,
                label: 'Notifications',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationScreen()));
                },
              ),
              InfoTile(
                icon: Icons.privacy_tip_rounded,
                label: 'Privacy',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyScreen()));
                },
              ),
              InfoTile(
                icon: Icons.help_rounded,
                label: 'Help Center',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HelpScreen()));
                },
              ),
              InfoTile(
                icon: Icons.logout_rounded,
                label: 'Logout',
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // Perform a clean logout, clear role cache, and take user to Login.
                  await ApiClient.logout();
                  RoleStore.clear();
                  // Also clear any cached current-user profile so the next session starts clean.
                  try { CurrentUserStore.I.clear(); } catch (_) {}
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- UI Building Blocks ----------------

/// Section header with consistent spacing and style
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Card-like container to group related rows (e.g., contacts, settings)
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
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i != 0) Divider(height: 1, color: cs.outlineVariant),
            // Match provider: do not add extra horizontal padding here; rely on ListTile contentPadding
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Compact chip to show verification status consistently
class _StatusChip extends StatelessWidget {
  final String status; // verified | pending | review | failed
  const _StatusChip({required this.status});

  Color _bg(BuildContext ctx) {
    final t = Theme.of(ctx);
    switch (status) {
      case 'verified':
        return t.colorScheme.primary.withOpacity(0.12);
      case 'review':
        return t.colorScheme.tertiary.withOpacity(0.12);
      case 'failed':
        return t.colorScheme.error.withOpacity(0.12);
      default:
        return t.colorScheme.secondary.withOpacity(0.12);
    }
  }

  Color _fg(BuildContext ctx) {
    final t = Theme.of(ctx);
    switch (status) {
      case 'verified':
        return t.colorScheme.primary;
      case 'review':
        return t.colorScheme.tertiary;
      case 'failed':
        return t.colorScheme.error;
      default:
        return t.colorScheme.secondary;
    }
  }

  String _label() {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'review':
        return 'In review';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  IconData _icon() {
    switch (status) {
      case 'verified':
        return Icons.verified;
      case 'review':
        return Icons.hourglass_bottom;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: 16, color: _fg(context)),
          const SizedBox(width: 6),
          Text(_label(), style: TextStyle(color: _fg(context), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// KYC tile that sits in the Identity section and launches the flow
class _KycTile extends StatelessWidget {
  final String status; // normalized by _kycStatus()
  final VoidCallback onTap;

  const _KycTile({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = status == 'verified';
    return _SectionCard(
      children: [
        ListTile(
          // Align with provider tiles: add horizontal padding and neutral icon container
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            // Use the same icon as Provider Identity Verification for consistency
            child: Icon(Icons.verified_user_outlined, color: theme.colorScheme.onSurfaceVariant),
          ),
          title: const Text('Identity Verification'),
          subtitle: Text(
            isVerified
                ? 'Your identity is verified.'
                : 'Verify your identity to keep your account secure.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          // Mirror provider: show a pill (green Verified / primary Verify) and no chevron when verified
          trailing: _StatusPillClient(
            label: isVerified ? 'Verified' : 'Verify',
            positive: isVerified,
          ),
          onTap: isVerified ? null : onTap,
        ),
      ],
    );
  }
}

/// Small pill used to mirror provider identity status styling on the client profile
class _StatusPillClient extends StatelessWidget {
  const _StatusPillClient({required this.label, this.positive = false});
  final String label; final bool positive;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color base = positive ? Colors.green : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: base.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: base.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: base, fontWeight: FontWeight.w600)),
    );
  }
}

/// Small circular verified badge shown next to the user name when KYC is verified
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.verified, size: 18, color: t.colorScheme.primary),
    );
  }
}
