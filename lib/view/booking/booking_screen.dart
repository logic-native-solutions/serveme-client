import 'package:flutter/material.dart';
import 'package:client/api/jobs_api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/view/home/location_store.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: _BookingScreen());
  }
}

class _BookingScreen extends StatefulWidget {
  const _BookingScreen();

  @override
  State<_BookingScreen> createState() => _BookingScreenState();
}

enum _BookingFilter { all, upcoming, past }


class _BookingScreenState extends State<_BookingScreen> {
  _BookingFilter _filter = _BookingFilter.all;

  bool _loading = true;
  String? _error;
  List<_Booking> _bookings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await JobsApi.I.listJobs(role: 'client');
      setState(() {
        _bookings = jobs.map(_mapJobToBooking).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load bookings';
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookings updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = Theme.of(context);
    final upcoming = _bookings.where((b) => b.isUpcoming).toList();
    final past = _bookings.where((b) => !b.isUpcoming).toList();

    List<_Booking> applyFilter() {
      switch (_filter) {
        case _BookingFilter.upcoming:
          return upcoming;
        case _BookingFilter.past:
          return past;
        case _BookingFilter.all:
        return _bookings;
      }
    }

    final visible = applyFilter();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 4),
              FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Bookings',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // Filter bar (All · Upcoming · Past)
            SegmentedButton<_BookingFilter>(
              segments: const [
                ButtonSegment(value: _BookingFilter.all, label: Text('All'), icon: Icon(Icons.list_alt)),
                ButtonSegment(value: _BookingFilter.upcoming, label: Text('Upcoming'), icon: Icon(Icons.event_available)),
                ButtonSegment(value: _BookingFilter.past, label: Text('Past'), icon: Icon(Icons.history)),
              ],
              selected: <_BookingFilter>{_filter},
              onSelectionChanged: (s) {
                setState(() => _filter = s.first);
              },
            ),
            const SizedBox(height: 12),

            if (_filter == _BookingFilter.all) ...[
              _SectionHeader(label: 'Upcoming'),
              const SizedBox(height: 8),
              ...upcoming.map((b) => _BookingTile(booking: b)),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader(label: 'Past'),
                const SizedBox(height: 8),
                ...past.map((b) => _BookingTile(booking: b)),
              ],
            ] else ...[
              // Single list when a filter is active
              ...visible.map((b) => _BookingTile(booking: b)),
            ],
          ],
        ),
      ),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

_Booking _mapJobToBooking(Job j) {
  final status = (j.status).toLowerCase();
  final upcomingStatuses = {
    'pending','assigned','enroute','arrived','in_progress'
  };
  final isUpcoming = upcomingStatuses.contains(status);
  String displayPrice = '';
  if (j.price != null) {
    final amt = (j.price!.total / 100).toStringAsFixed(2);
    displayPrice = '${j.price!.currency} $amt';
  }
  String when = '';
  final dt = j.createdAt ?? j.acceptedAt ?? j.completedAt;
  if (dt != null) {
    final d = dt.toLocal();
    when = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }
  // Map serviceType -> image asset (fallback generic)
  final img = _imageForServiceType(j.serviceType);
  return _Booking(
    jobId: j.id,
    assignedProviderId: j.assignedProviderId,
    title: j.serviceType, // replace with display label when available
    when: when.isEmpty ? '—' : when,
    isUpcoming: isUpcoming,
    imagePath: img,
    status: j.status,
    price: displayPrice,
    provider: '',
    rating: null,
  );
}

String _imageForServiceType(String t) {
  switch (t.toLowerCase()) {
    case 'cleaner':
    case 'home_cleaning':
    case 'cleaning':
      return 'assets/images/Home_Cleaning_Cat.png';
    case 'plumber':
      return 'assets/images/Plumbing_Cat.png';
    case 'painting':
      return 'assets/images/Painting_Cat.png';
    default:
      return 'assets/images/Home_Cleaning_Cat.png';
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});
  final _Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceVariant = theme.colorScheme.surfaceContainerHighest;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openDetails(context, booking),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumb
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 52,
                height: 52,
                color: surfaceVariant,
                child: Image.asset(
                  booking.imagePath,
                  fit: BoxFit.cover,
                  width: 52,
                  height: 52,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Title + subtitle + provider/rating with status chip
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          booking.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (booking.status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            booking.status,
                            style: theme.textTheme.labelSmall?.copyWith(color: onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    booking.when,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (booking.provider.isNotEmpty || booking.rating != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (booking.provider.isNotEmpty) booking.provider,
                        if (booking.rating != null) '· ⭐ ${booking.rating!.toStringAsFixed(1)}',
                      ].join(' '),
                      style: theme.textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // trailing price + chevron
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, _Booking b) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(b.imagePath, width: 56, height: 56, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(b.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(b.when, style: theme.textTheme.bodyMedium),
              if (b.provider.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('With ${b.provider}', style: theme.textTheme.bodyMedium),
              ],
              if (b.price.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Price: ${b.price}', style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (b.isUpcoming) ...[
                    // Reschedule would open a date/time picker. Left as TODO, only wiring actions requested in issue.
                    FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.edit_calendar), label: const Text('Reschedule')),
                    // Contact: navigate to the Messages screen. If no provider yet, show an info message.
                    OutlinedButton.icon(
                      onPressed: () {
                        if (b.assignedProviderId == null || b.assignedProviderId!.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('A provider has not been assigned yet. We\'ll notify you once connected.')),
                          );
                          return;
                        }
                        Navigator.of(ctx).pushNamed('/message');
                      },
                      icon: const Icon(Icons.chat_bubble),
                      label: const Text('Contact'),
                    ),
                    // Directions: open Maps with the best available location hint.
                    OutlinedButton.icon(
                      onPressed: () async {
                        // Try to use the currently selected address from LocationStore (shared with headers)
                        final addr = LocationStore.I.address;
                        if (addr == null || addr.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('No address available for directions. Set your location in profile.')),
                          );
                          return;
                        }

                        // Build a universal Maps fallback URL. We prefer launching directly and
                        // checking the boolean result instead of calling canLaunchUrl first.
                        // Rationale: On iOS, canLaunchUrl may throw a channel-error after a hot
                        // restart if the plugin channel hasn't reattached yet. Using launchUrl
                        // directly avoids that crash; we handle the false return and exceptions.
                        final q = Uri.encodeComponent(addr);
                        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
                        try {
                          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                          if (!ok) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Could not open Maps on this device.')),
                            );
                          }
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Could not open Maps on this device.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.pin_drop),
                      label: const Text('Directions'),
                    ),
                    // Cancel: call backend and then close the sheet.
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await JobsApi.I.updateStatus(b.jobId, 'canceled');
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Booking canceled. Pull to refresh to update the list.')),
                          );
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Failed to cancel booking. Please try again.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                    ),
                  ] else ...[
                    FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.refresh), label: const Text('Rebook')),
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.receipt_long), label: const Text('Invoice')),
                    TextButton.icon(onPressed: () {}, icon: const Icon(Icons.star_rate), label: const Text('Rate')),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              SafeArea(top: false, child: SizedBox(height: 4)),
            ],
          ),
        );
      },
    );
  }
}

class _Booking {
  final String jobId;           // Backend job identifier
  final String? assignedProviderId; // Null until assigned
  final String title;
  final String when;
  final bool isUpcoming;
  final String imagePath; // thumbnail from assets
  final String status;    // e.g., 'Upcoming', 'Completed'
  final String price;     // e.g., 'R350' or 'R180/hr'
  final String provider;  // e.g., 'Thabo M.'
  final double? rating;   // optional rating

  const _Booking({
    required this.jobId,
    required this.assignedProviderId,
    required this.title,
    required this.when,
    required this.isUpcoming,
    required this.imagePath,
    this.status = '',
    this.price = '',
    this.provider = '',
    this.rating,
  });
}
