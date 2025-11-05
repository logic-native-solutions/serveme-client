import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/api/jobs_api.dart';

/// OngoingRequestCard
/// -------------------
/// Shows the user's most relevant active request with quick actions.
/// Data source: JobsApi.listJobs(role:'client'), selecting the latest job with
/// status in {pending, assigned, en_route, in_progress}.
///
/// Notes
/// - Provider name and rating are not available on Job yet; placeholders are
///   used with clear comments to wire later when backend exposes provider info.
/// - "Call Provider" uses tel: scheme only when a number is available.
/// - Fully theme-aware for dark mode by relying on ThemeData color roles.
class OngoingRequestCard extends StatefulWidget {
  const OngoingRequestCard({super.key});

  @override
  State<OngoingRequestCard> createState() => _OngoingRequestCardState();
}

class _OngoingRequestCardState extends State<OngoingRequestCard> {
  bool _loading = true;
  Job? _job;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await JobsApi.I.listJobs(role: 'client');
      // pick most recent active job
      Job? pick;
      final active = jobs.where((j) {
        final s = j.status.toLowerCase();
        return s == 'pending' || s == 'assigned' || s == 'en_route' || s == 'in_progress';
      }).toList();
      if (active.isNotEmpty) {
        active.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        pick = active.first;
      }
      setState(() {
        _job = pick;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load ongoing request';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const SizedBox.shrink();
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      );
    }
    if (_job == null) {
      // Nothing active – don't render the card at all to keep dashboard tidy.
      return const SizedBox.shrink();
    }
    final j = _job!;

    // Derive friendly values
    final serviceName = _toTitle(j.serviceType);
    final providerName = j.assignedProviderId != null && j.assignedProviderId!.isNotEmpty
        ? 'Assigned provider'
        : 'Searching for provider…';
    final eta = _guessEta(j);
    final ratingText = j.assignedProviderId != null ? '4.9' : '—'; // TODO: bind real provider rating

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x14000000))],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timelapse, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Ongoing Request',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.home_repair_service, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(serviceName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(providerName, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      [if (eta != null) 'ETA ~ $eta', '⭐ $ratingText'].where((s) => s.isNotEmpty).join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/tracking'),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Track'),
              ),
              OutlinedButton.icon(
                onPressed: () => _callProvider(context),
                icon: const Icon(Icons.call),
                label: const Text('Call Provider'),
              ),
              TextButton.icon(
                onPressed: () => _cancel(context, j),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Request'),
              ),
            ],
          )
        ],
      ),
    );
  }

  String _toTitle(String s) {
    if (s.isEmpty) return 'Service';
    return s.replaceAll('_', ' ').replaceFirst(s[0], s[0].toUpperCase());
  }

  String? _guessEta(Job j) {
    // With no live ETA on Job, approximate: if accepted <now, add 25m>; if pending, show null.
    if (j.acceptedAt != null) {
      return '25 mins';
    }
    return null;
  }

  Future<void> _callProvider(BuildContext context) async {
    // TODO: Replace with provider.phone from job assignment payload
    const String? phone = null;
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider phone not available yet')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call')),
      );
    }
  }

  Future<void> _cancel(BuildContext context, Job j) async {
    try {
      await JobsApi.I.updateStatus(j.id, 'canceled');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request canceled')),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel request')),
      );
    }
  }
}
