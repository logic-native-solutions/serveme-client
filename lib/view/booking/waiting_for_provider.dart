import 'dart:async';

import 'package:client/api/jobs_api.dart';
import 'package:flutter/material.dart';

/// WaitingForProviderScreen
/// - Minimal client-side waiting screen after creating a job.
/// - Polls GET /api/v1/jobs/{id} every 5s until status != pending.
/// - When assigned, shows provider assigned message; (later) navigate to job details.
class WaitingForProviderScreen extends StatefulWidget {
  static const String route = '/jobs/waiting';
  final String jobId;
  const WaitingForProviderScreen({super.key, required this.jobId});

  @override
  State<WaitingForProviderScreen> createState() => _WaitingForProviderScreenState();
}

class _WaitingForProviderScreenState extends State<WaitingForProviderScreen> {
  Job? _job;
  String? _error;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final job = await JobsApi.I.getJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load job';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final job = _job;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Submitted'), centerTitle: false),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 40,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.watch_later_outlined, color: cs.onPrimaryContainer, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Waiting for a provider…', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'We\'ve notified nearby providers. You\'ll be able to track them once one accepts your request.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: cs.error)),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: _fetch, child: const Text('Retry')),
            ],
            const SizedBox(height: 16),
            if (job != null) _StatusBlock(job: job),
            const SizedBox(height: 12),
            if (job?.fanOutCount != null)
              Text('Notified ${job!.fanOutCount} provider${job!.fanOutCount == 1 ? '' : 's'} nearby',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  final Job job;
  const _StatusBlock({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final assigned = job.assignedProviderId != null && job.assignedProviderId!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(assigned ? Icons.check_circle_outline : Icons.hourglass_bottom, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                assigned ? 'Provider Assigned' : 'Pending Offers',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Status: ${job.status}'),
          if (job.price != null) ...[
            const SizedBox(height: 4),
            Text('Total: ${job.price!.currency} ${(job.price!.total / 100).toStringAsFixed(2)}'),
          ],
        ],
      ),
    );
  }
}
