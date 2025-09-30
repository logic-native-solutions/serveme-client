import 'package:flutter/material.dart';

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
  // ---------------------------------------------------------------------------
  // Mock data for now – wire to your API/store later.
  // ---------------------------------------------------------------------------
  // Simple filter for the list

  _BookingFilter _filter = _BookingFilter.all;

  final List<_Booking> _bookings = const [
    _Booking(
      title: 'House Cleaning',
      when: 'Tomorrow, 10:00 AM',
      isUpcoming: true,
      imagePath: 'assets/images/Home_Cleaning_Cat.png',
      status: 'Upcoming',
      price: 'R350',
      provider: 'Lerato M.',
      rating: 4.9,
    ),
    _Booking(
      title: 'Elderly Care',
      when: 'Next week, 2:00 PM',
      isUpcoming: true,
      imagePath: 'assets/images/Elderly_Care_Cat.png',
      status: 'Upcoming',
      price: 'R180/hr',
      provider: 'Thabo S.',
      rating: 4.8,
    ),
    _Booking(
      title: 'Plumbing Repair',
      when: 'Last month, 3:00 PM',
      isUpcoming: false,
      imagePath: 'assets/images/Plumbing_Cat.png',
      status: 'Completed',
      price: 'R650',
      provider: 'Nomsa K.',
      rating: 4.7,
    ),
    _Booking(
      title: 'Painting',
      when: '2 months ago, 11:00 AM',
      isUpcoming: false,
      imagePath: 'assets/images/Painting_Cat.png',
      status: 'Completed',
      price: 'R1200',
      provider: 'Sizwe P.',
      rating: 4.6,
    ),
  ];

  Future<void> _handleRefresh() async {
    // TODO: wire this to your real API/store reload
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bookings refreshed'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
      ),
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
                    FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.edit_calendar), label: const Text('Reschedule')),
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.chat_bubble), label: const Text('Contact')),
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.pin_drop), label: const Text('Directions')),
                    TextButton.icon(onPressed: () {}, icon: const Icon(Icons.cancel), label: const Text('Cancel')),
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
  final String title;
  final String when;
  final bool isUpcoming;
  final String imagePath; // thumbnail from assets
  final String status;    // e.g., 'Upcoming', 'Completed'
  final String price;     // e.g., 'R350' or 'R180/hr'
  final String provider;  // e.g., 'Thabo M.'
  final double? rating;   // optional rating

  const _Booking({
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
