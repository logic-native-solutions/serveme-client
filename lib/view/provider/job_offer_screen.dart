import 'dart:async';

import 'package:client/api/jobs_api.dart';
import 'package:flutter/material.dart';

/// ProviderJobOfferScreen
///
/// Purpose
///  • Display a single job offer pushed via FCM (type=job_offer).
///  • Fetch latest job details from backend and show key fields.
///  • Allow provider to Accept the job; handle backend validation errors.
///
/// Navigation
///  • Route: ProviderJobOfferScreen.route
///  • Arguments: jobId (String)
class ProviderJobOfferScreen extends StatefulWidget {
  static const String route = '/provider/job-offer';
  final String jobId;
  const ProviderJobOfferScreen({super.key, required this.jobId});

  @override
  State<ProviderJobOfferScreen> createState() => _ProviderJobOfferScreenState();
}

class _ProviderJobOfferScreenState extends State<ProviderJobOfferScreen> {
  Job? _job;
  String? _error;
  bool _busy = false;
  Timer? _timer; // for countdown updates

  @override
  void initState() {
    super.initState();
    _load();
    // Tick every second to refresh countdown if expiresAt present.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final job = await JobsApi.I.getJob(widget.jobId);
      if (!mounted) return;
      setState(() => _job = job);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load job');
    }
  }

  Duration? _remaining() {
    final expiresAt = _job?.expiresAt;
    if (expiresAt == null) return null;
    final now = DateTime.now().toUtc();
    final diff = expiresAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _accept() async {
    setState(() { _busy = true; _error = null; });
    try {
      final job = await JobsApi.I.acceptJob(widget.jobId);
      if (!mounted) return;
      setState(() => _job = job);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job accepted')));
      Navigator.of(context).pop();
    } on Exception catch (e) {
      final msg = e.toString();
      String human = 'Failed to accept';
      // Backend contract per documentation.
      if (msg.contains('409') && msg.contains('expired')) {
        human = 'Offer expired';
      } else if (msg.contains('409') && msg.contains('already_taken')) human = 'Job already taken';
      else if (msg.contains('403') && msg.contains('not_offered')) human = 'This offer is not available to you';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(human)));
      setState(() { _error = human; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final job = _job;
    final remaining = _remaining();

    return Scaffold(
      appBar: AppBar(title: const Text('New Job Offer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: job == null
            ? Center(
                child: _error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: cs.error)),
                          const SizedBox(height: 8),
                          FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
                        ],
                      )
                    : const CircularProgressIndicator(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header / Service type
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.work_outline, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job.serviceType, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            if (remaining != null)
                              Text('Expires in ${_formatDuration(remaining)}', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if ((job.description ?? '').isNotEmpty) ...[
                    Text('Description', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(job.description!),
                    const SizedBox(height: 12),
                  ],

                  // Price
                  if (job.price != null) ...[
                    Text('Total', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${job.price!.currency} ${(job.price!.total / 100).toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                  ],

                  const Spacer(),

                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: cs.error)),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _accept,
                          child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Accept Job'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
