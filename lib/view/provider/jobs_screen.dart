import 'package:flutter/material.dart';

/// ProviderJobsScreen
/// -------------------
/// Template for the Provider “Jobs” tab/area. It follows the uploaded designs
/// for:
///  • Jobs overview with sections: Active Jobs, Scheduled, Past Fulfilled
///  • Incoming job request popup with client details and Accept/Decline actions
///  • Decline Reason sheet → Declined Confirmation modal
///  • Accepted Confirmation modal
///
/// Notes
/// -----
/// - All data here is mocked. Replace with your backend/store when ready.
/// - Colors, fonts, and rounding match the rest of the app (Material 3 +
///   AnonymousPro for section headings).
/// - This is a single file on purpose so you can inspect the whole flow.
class ProviderJobsScreen extends StatefulWidget {
  const ProviderJobsScreen({super.key});

  static const String route = '/provider/jobs';

  @override
  State<ProviderJobsScreen> createState() => _ProviderJobsScreenState();
}

class _ProviderJobsScreenState extends State<ProviderJobsScreen> {
  // Selected sub-tab in this screen: 0=Active, 1=Scheduled, 2=Past
  int _tabIndex = 0;

  // Mock data for the lists (replace with repository/store later)
  final List<_JobCardData> _active = const [
    _JobCardData(
      statusLabel: 'In Progress',
      title: 'Home Cleaning',
      client: 'Sarah Miller',
      imageUrl: 'https://picsum.photos/seed/homeclean/300/200',
    ),
  ];

  final List<_JobCardData> _scheduled = const [
    _JobCardData(
      statusLabel: 'Scheduled',
      title: 'Plumbing Repair',
      client: 'David Lee',
      imageUrl: 'https://picsum.photos/seed/plumb/300/200',
    ),
  ];

  final List<_JobCardData> _past = const [
    _JobCardData(
      statusLabel: 'Completed',
      title: 'Electrical Installation',
      client: 'Emily Chen',
      imageUrl: 'https://picsum.photos/seed/elect/300/200',
    ),
    _JobCardData(
      statusLabel: 'Completed',
      title: 'Landscaping',
      client: 'Michael Brown',
      imageUrl: 'https://picsum.photos/seed/land/300/200',
    ),
  ];

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
              Row(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Jobs',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),

                  IconButton(
                    tooltip: 'Simulate new request',
                    icon: const Icon(Icons.add_alert_outlined),
                    onPressed: _showIncomingJobRequest,
                  )
                ],

              ),

              SizedBox(height: 16,),
              // Mirror client Booking screen: use SegmentedButton for filters
              // Wrap with Center + ConstrainedBox so the control remains a stable width
              // and stays centered when switching filters. This prevents minor jiggles
              // caused by parent width recalculations and ensures visual consistency.
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('All')),
                      ButtonSegment(value: 1, label: Text('Active')),
                      ButtonSegment(value: 2, label: Text('Sched')),
                      ButtonSegment(value: 3, label: Text('Past')),
                    ],
                    selected: <int>{_tabIndex},
                    onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sections per selected filter (mirrors Booking screen structure)
              if (_tabIndex == 0) ...[
                // All → show Upcoming/Scheduled first, then Active (if distinct), then Past
                if (_active.isNotEmpty) ...[
                  _sectionHeader('Active'),
                  const SizedBox(height: 8),
                  ..._active.map((j) => _jobListTile(j)),
                ],
                if (_scheduled.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionHeader('Scheduled'),
                  const SizedBox(height: 8),
                  ..._scheduled.map((j) => _jobListTile(j)),
                ],
                if (_past.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionHeader('Past'),
                  const SizedBox(height: 8),
                  ..._past.map((j) => _jobListTile(j)),
                ],
              ] else if (_tabIndex == 1) ...[
                _sectionHeader('Active'),
                const SizedBox(height: 8),
                ..._active.map((j) => _jobListTile(j)),
              ] else if (_tabIndex == 2) ...[
                _sectionHeader('Scheduled'),
                const SizedBox(height: 8),
                ..._scheduled.map((j) => _jobListTile(j)),
              ] else ...[
                _sectionHeader('Past'),
                const SizedBox(height: 8),
                ..._past.map((j) => _jobListTile(j)),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helpers to mirror client Booking tile layout -------------------------
  Widget _sectionHeader(String label) {
    final theme = Theme.of(context);
    return Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700));
  }

  Widget _statusPill(String label, Color color) {
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

  Color _statusColor(String status) {
    final cs = Theme.of(context).colorScheme;
    final s = status.toLowerCase();
    if (s.contains('progress') || s.contains('active')) return cs.primary;
    if (s.contains('schedule')) return cs.tertiary;
    if (s.contains('complete') || s.contains('past')) return cs.onSurfaceVariant;
    return cs.onSurfaceVariant;
  }

  Widget _jobListTile(_JobCardData data) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job details (placeholder')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 52,
                height: 52,
                color: cs.surfaceContainerHighest,
                child: Image.network(data.imageUrl, fit: BoxFit.cover, width: 52, height: 52),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusPill(data.statusLabel, _statusColor(data.statusLabel)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Client: ${data.client}', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Incoming Job Request flow
  // ---------------------------------------------------------------------------
  void _showIncomingJobRequest() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _IncomingJobDialog(
        onAccept: () => Navigator.of(context).pop(true),
        onDecline: () => Navigator.of(context).pop(false),
      ),
    );

    if (!mounted) return;

    if (accepted == true) {
      // Show Accepted confirmation
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _AcceptedDialog(),
      );
    } else if (accepted == false) {
      // Ask for decline reason first
      final reason = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => const _DeclineReasonSheet(),
      );
      if (!mounted) return;
      // After reason captured, show Declined confirmation
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DeclinedDialog(reason: reason),
      );
    }
  }
}

// ============================================================================
// UI Building Blocks
// ----------------------------------------------------------------------------

class _Segmented3 extends StatelessWidget {
  const _Segmented3({required this.index, required this.labels, required this.onChanged});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final selected = index == i;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(i == 0
                  ? 12
                  : i == 2
                      ? 12
                      : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? cs.primary.withOpacity(0.10) : null,
                  borderRadius: i == 0
                      ? const BorderRadius.horizontal(left: Radius.circular(12))
                      : i == 2
                          ? const BorderRadius.horizontal(right: Radius.circular(12))
                          : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.primary : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _JobCardData {
  final String statusLabel;
  final String title;
  final String client;
  final String imageUrl;
  const _JobCardData({required this.statusLabel, required this.title, required this.client, required this.imageUrl});
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _JobListTile extends StatelessWidget {
  const _JobListTile({required this.data});
  final _JobCardData data;

  Color _statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = data.statusLabel.toLowerCase();
    if (s.contains('progress') || s.contains('active')) return cs.primary;
    if (s.contains('schedule')) return cs.tertiary;
    if (s.contains('complete') || s.contains('past')) return cs.onSurfaceVariant;
    return cs.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        // TODO: Navigate to job details when implemented
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job details (placeholder)')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 52,
                height: 52,
                color: cs.surfaceContainerHighest,
                child: Image.network(
                  data.imageUrl,
                  fit: BoxFit.cover,
                  width: 52,
                  height: 52,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Title + client + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(label: data.statusLabel, color: _statusColor(context)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Client: ${data.client}',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label; final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.data});
  final _JobCardData data;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(data.imageUrl, width: 110, height: 90, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.statusLabel, style: text.labelLarge?.copyWith(color: cs.primary)),
                  const SizedBox(height: 4),
                  Text(
                    data.title,
                    style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Client: ${data.client}', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () {},
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------ Incoming Request Dialog ---------------------------
class _IncomingJobDialog extends StatelessWidget {
  const _IncomingJobDialog({required this.onAccept, required this.onDecline});
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text('New Job Request', style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
                  ),
                ),
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Client John Doe requests: Leaky Faucet Repair',
              style: text.bodyLarge,
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.place_outlined, title: 'Location', subtitle: '123 Elm Street, Anytown'),
            _InfoRow(icon: Icons.calendar_month_outlined, title: 'Date & Time', subtitle: 'Tomorrow, 2 PM'),
            _InfoRow(icon: Icons.attach_money, title: 'Payment', subtitle: 'R500'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    child: const Text('Accept Job'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: text.bodyMedium),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------- Decline Reason Sheet -------------------------
class _DeclineReasonSheet extends StatefulWidget {
  const _DeclineReasonSheet();
  @override
  State<_DeclineReasonSheet> createState() => _DeclineReasonSheetState();
}

class _DeclineReasonSheetState extends State<_DeclineReasonSheet> {
  int _selected = 0; // 0..3 for preset, 4 for other
  final TextEditingController _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Center(child: Text('Decline job', style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Why are you declining this job?', style: text.titleMedium),
          const SizedBox(height: 12),
          ...List.generate(4, (i) {
            final label = [
              'Not available',
              'Too far',
              'Service out of scope',
              'Other',
            ][i];
            final selected = _selected == i;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                onTap: () => setState(() => _selected = i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(label)),
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          // Free text when Other selected
          if (_selected == 3)
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _other,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Please specify',
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final reason = _selected == 0
                    ? 'Not available'
                    : _selected == 1
                        ? 'Too far'
                        : _selected == 2
                            ? 'Service out of scope'
                            : (_other.text.trim().isEmpty ? 'Other' : _other.text.trim());
                Navigator.of(context).pop(reason);
              },
              child: const Text('Decline job'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------- Declined Confirmation ------------------------
class _DeclinedDialog extends StatelessWidget {
  const _DeclinedDialog({this.reason});
  final String? reason;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(child: Center(child: Text('Job Declined', style: text.titleLarge))),
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Job Declined', style: text.displaySmall?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'You have successfully declined the job. The client has been notified.' + (reason == null ? '' : '\nReason: ${reason!}'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go to Jobs Overview'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Browse New Jobs'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------- Accepted Confirmation ------------------------
class _AcceptedDialog extends StatelessWidget {
  const _AcceptedDialog();
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
                Expanded(child: Center(child: Text('Job Accepted', style: text.titleLarge))),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "You've accepted the job!",
                style: text.displaySmall?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You're now responsible for completing this task. Please review the details and prepare to start.",
            ),
            const SizedBox(height: 16),
            Text('Job Summary', style: text.titleMedium?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const _InfoRow(icon: Icons.build_outlined, title: 'Leaky Faucet Repair', subtitle: 'Plumbing'),
            const _InfoRow(icon: Icons.place_outlined, title: 'Location', subtitle: '123 Elm Street, Anytown'),
            const _InfoRow(icon: Icons.calendar_month_outlined, title: 'Date & Time', subtitle: 'Tomorrow, 2 PM'),
            const _InfoRow(icon: Icons.attach_money, title: 'Payment', subtitle: 'R50'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('View Job Details'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
