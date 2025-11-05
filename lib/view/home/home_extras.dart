import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:client/api/jobs_api.dart' as jobs;
import 'package:client/api/services_api.dart';
import 'package:client/service/referral_service.dart';

/// Home dashboard extra sections used on the client Home screen.
/// These widgets are theme-aware and safe to show even without backend data.
/// Each section is intentionally self-contained to keep HomeScreen lean.

// ----------------------------------------------------------------------------
// UpcomingBookingsSection
// ----------------------------------------------------------------------------
class UpcomingBookingsSection extends StatefulWidget {
  const UpcomingBookingsSection({super.key});

  @override
  State<UpcomingBookingsSection> createState() => _UpcomingBookingsSectionState();
}

class _UpcomingBookingsSectionState extends State<UpcomingBookingsSection> {
  bool _loading = true;
  List<jobs.Job> _upcoming = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await jobs.JobsApi.I.listJobs(role: 'client');
      // Heuristic upcoming: not completed and not canceled.
      final now = DateTime.now();
      List<jobs.Job> filt = list.where((j) {
        final s = j.status.toLowerCase();
        if (s == 'completed' || s == 'canceled') return false;
        // Treat recently created/accepted as upcoming if within next 7 days.
        final ref = j.acceptedAt ?? j.createdAt ?? now;
        return ref.isAfter(now.subtract(const Duration(days: 1))) && ref.isBefore(now.add(const Duration(days: 7)));
      }).toList();
      filt.sort((a, b) => (a.acceptedAt ?? a.createdAt ?? DateTime.now())
          .compareTo(b.acceptedAt ?? b.createdAt ?? DateTime.now()));
      setState(() {
        _upcoming = filt.take(5).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() { _loading = false; _upcoming = const []; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const SizedBox.shrink();
    if (_upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Upcoming Bookings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        ..._upcoming.map((j) => _UpcomingCard(job: j)).toList(),
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.job});
  final jobs.Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = _toTitle(job.serviceType);
    final when = _formatWhen(job);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0,2), color: Color(0x12000000))],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        color: theme.cardColor,
      ),
      child: Stack(
        children: [
          // left accent bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.event_available, color: scheme.secondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(when, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _toTitle(String s) => s.isEmpty ? 'Service' : s.replaceAll('_', ' ').replaceFirst(s[0], s[0].toUpperCase());
  String _formatWhen(jobs.Job j) {
    // In absence of a scheduled time field, derive from acceptedAt/createdAt.
    final dt = j.acceptedAt ?? j.createdAt ?? DateTime.now();
    final w = _weekday(dt.weekday);
    final hm = _pad(dt.hour) + ':' + _pad(dt.minute);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isTomorrow = dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day;
    if (isTomorrow) return 'Tomorrow at $hm';
    return dt.day == now.day && dt.month == now.month && dt.year == now.year ? 'Today at $hm' : '$w, $hm';
  }
  String _weekday(int w) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][w-1];
  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ----------------------------------------------------------------------------
// RecommendedSection
// ----------------------------------------------------------------------------
class RecommendedSection extends StatelessWidget {
  const RecommendedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Recommended for You', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 128,
          child: FutureBuilder<List<ServiceDoc>>(
            future: ServicesApi.I.fetchServices(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)));
              }
              if (!snap.hasData || snap.data!.isEmpty) {
                return Center(child: Text('No suggestions right now', style: theme.textTheme.bodySmall));
              }
              final items = snap.data!;
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length.clamp(0, 10),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final s = items[i];
                  return _RecommendationChip(
                    title: s.displayName,
                    subtitle: i % 3 == 0 ? 'Popular near you' : (i % 3 == 1 ? 'Top-rated' : 'Based on your last booking'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  const _RecommendationChip({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, scheme.secondaryContainer.withOpacity(0.35)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          FilledButton.tonal(
            onPressed: () => Navigator.pushNamed(context, '/all-services', arguments: {'serviceName': title}),
            child: const Text('Book'),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// RecentActivitySection
// ----------------------------------------------------------------------------
class RecentActivitySection extends StatefulWidget {
  const RecentActivitySection({super.key});
  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<RecentActivitySection> {
  bool _loading = true;
  jobs.Job? _lastCompleted;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await jobs.JobsApi.I.listJobs(role: 'client');
      // Filter to completed jobs only and pick the latest one.
      final completed = list.where((j) => j.completedAt != null || j.status.toLowerCase() == 'completed').toList();
      completed.sort((a, b) => (b.completedAt ?? b.acceptedAt ?? b.createdAt ?? DateTime(0))
          .compareTo(a.completedAt ?? a.acceptedAt ?? a.createdAt ?? DateTime(0)));
      setState(() { _lastCompleted = completed.isNotEmpty ? completed.first : null; _loading = false; });
    } catch (_) { setState(() { _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_lastCompleted == null) return const SizedBox.shrink();
    // Show a focused "Last booked" card with a Rebook action for quick repeat.
    return _LastBookedCard(job: _lastCompleted!);
  }
}

/// Compact card that highlights the user's most recent completed booking
/// and provides a single-tap Rebook action. Theme-aware and dark-mode safe.
class _LastBookedCard extends StatelessWidget {
  const _LastBookedCard({required this.job});
  final jobs.Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final serviceTitle = _toTitle(job.serviceType);
    final when = job.completedAt ?? job.acceptedAt ?? job.createdAt;
    final whenText = when != null ? _ago(when) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x14000000))],
      ),
      child: Row(
        children: [
          // Icon capsule
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.refresh_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last booked', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(serviceTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (whenText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(whenText, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {
              // Navigate to All Services and auto-open the request sheet for this service.
              Navigator.pushNamed(context, '/all-services', arguments: {'serviceTypeId': job.serviceType});
            },
            child: const Text('Rebook'),
          ),
        ],
      ),
    );
  }

  String _toTitle(String s) => s.isEmpty ? 'Service' : s.replaceAll('_', ' ').replaceFirst(s[0], s[0].toUpperCase());
  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays >= 1) return '${d.inDays} day${d.inDays==1?'':'s'} ago';
    if (d.inHours >= 1) return '${d.inHours} hour${d.inHours==1?'':'s'} ago';
    if (d.inMinutes >= 1) return '${d.inMinutes} min${d.inMinutes==1?'':'s'} ago';
    return 'just now';
  }
}

// ----------------------------------------------------------------------------
// AnnouncementsBanner
// ----------------------------------------------------------------------------
class AnnouncementsBanner extends StatelessWidget {
  const AnnouncementsBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          colors: [scheme.surface, scheme.primaryContainer.withOpacity(0.25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.campaign, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Announcements', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('New verified providers added in your area.\nWe\'ve improved our safety measures.', style: theme.textTheme.bodySmall),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// SafetyTrustBadge
// ----------------------------------------------------------------------------
class SafetyTrustBadge extends StatelessWidget {
  const SafetyTrustBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Blend-in variant: match card styling used elsewhere on Home (e.g., OngoingRequestCard).
    // - Use cardColor + subtle border instead of gradient
    // - Remove left accent bar to avoid looking "added later"
    // - Keep icon capsule and concise checklist
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x14000000))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon capsule (consistent with other home widgets)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.verified_rounded, color: scheme.primary, size: 26),
          ),
          const SizedBox(width: 12),
          // Text block with checklist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety & Trust',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                _Bullet(text: 'All providers verified for ID and background checks'),
                const SizedBox(height: 4),
                _Bullet(text: 'Secure, encrypted payments'),
                const SizedBox(height: 4),
                _Bullet(text: 'Trusted, rated professionals near you'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 16, color: cs.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// AppEducationSection: Light, lively, theme-blended education about ServeMe
// ----------------------------------------------------------------------------
/// A compact, auto-rotating set of educational cards that explain the value of
/// ServeMe to new and returning users. Designed to blend with the Home page
/// visuals and avoid looking static by using subtle animations, icons/images,
/// and Material 3 colors that adapt to dark mode.
class AppEducationSection extends StatefulWidget {
  const AppEducationSection({super.key});

  @override
  State<AppEducationSection> createState() => _AppEducationSectionState();
}

class _AppEducationSectionState extends State<AppEducationSection> {
  final PageController _pageCtrl = PageController(viewportFraction: 0.92);
  int _index = 0;
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  // Rotate every 4.5 seconds to keep it gentle.
  static const Duration kRotateEvery = Duration(milliseconds: 4500);

  @override
  void initState() {
    super.initState();
    // Simple ticker-driven auto-advance to avoid Timer lifecycle edge cases.
    _ticker = Ticker((elapsed) {
      // Only act when we cross the threshold since last page flip.
      if (elapsed - _elapsed >= kRotateEvery) {
        _elapsed = elapsed;
        if (!mounted) return;
        final next = (_index + 1) % _slides.length;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    if (_slides.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Why ServeMe?',
            style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        // Card carousel
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final s = _slides[i];
              return AnimatedBuilder(
                animation: _pageCtrl,
                builder: (context, child) {
                  // Subtle scale to give a lively feel
                  double scale = 1.0;
                  if (_pageCtrl.position.haveDimensions) {
                    final page = _pageCtrl.page ?? _pageCtrl.initialPage.toDouble();
                    final diff = (i - page).abs();
                    scale = 1 - (diff * 0.04).clamp(0, 0.08);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: _EducationCard(s: s, cs: cs, t: t),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final isActive = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? cs.primary : t.dividerColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _EducationSlide {
  final String title;
  final String subtitle;
  final String? asset; // optional asset path for supporting image
  final IconData? icon; // fallback icon if no asset
  const _EducationSlide({required this.title, required this.subtitle, this.asset, this.icon});
}

// Curated set of concise, positive messages. Keep short to avoid truncation.
const List<_EducationSlide> _slides = [
  _EducationSlide(
    title: 'Vetted pros, on demand',
    subtitle: 'Book cleaners, plumbers, electricians, and more in minutes.',
    asset: 'assets/images/all_category.png',
  ),
  _EducationSlide(
    title: 'We do the hard checks',
    subtitle: 'ID and background verification for peace of mind.',
    asset: 'assets/images/safety.png',
  ),
  _EducationSlide(
    title: 'Track and chat seamlessly',
    subtitle: 'Real-time updates and in-app messaging keep you in control.',
    icon: Icons.chat_bubble_rounded,
  ),
  _EducationSlide(
    title: 'Secure payments',
    subtitle: 'Safe, transparent payments with digital receipts.',
    icon: Icons.lock_rounded,
  ),
];

class _EducationCard extends StatelessWidget {
  final _EducationSlide s;
  final ColorScheme cs;
  final ThemeData t;
  const _EducationCard({required this.s, required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor.withValues(alpha: 0.5)),
        boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x14000000))],
      ),
      child: Row(
        children: [
          // Visual: asset image or icon capsule
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.28),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: s.asset != null
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(s.asset!, fit: BoxFit.contain),
                  )
                : Icon(s.icon ?? Icons.info_outline_rounded, color: cs.primary, size: 30),
          ),
          const SizedBox(width: 12),
          // Copy
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  s.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// ReferralBanner
// ----------------------------------------------------------------------------

class ReferralBanner extends StatelessWidget {
  const ReferralBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          colors: [scheme.surface, scheme.secondaryContainer.withOpacity(0.25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.card_giftcard, color: scheme.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Invite a friend and both get R50 credit.', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
          FilledButton.tonal(
            onPressed: () async {
              // Trigger the same Invite flow used in Profile.
              // Opens native share sheet with referral link.
              try {
                await ReferralService.shareInvite(context);
              } catch (_) {}
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }
}
