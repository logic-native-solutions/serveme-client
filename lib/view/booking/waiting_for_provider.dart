import 'dart:async';

import 'package:client/api/jobs_api.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui show lerpDouble;

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
            // Animated hero visual while we look for a provider (subtle, theme-aware)
            SizedBox(
              height: 200,
              width: 200,
              child: _SearchingPulse(icon: Icons.watch_later_outlined),
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

/// Animated pulse + orbiting dots to convey "searching" state similar to ride-hailing apps
/// - Theme-aware colors (uses ColorScheme)
/// - Lightweight: CustomPainter + two AnimationControllers
/// - Avoids heavy rebuilds by painting based on animation values
class _SearchingPulse extends StatefulWidget {
  final IconData icon;
  const _SearchingPulse({required this.icon});

  @override
  State<_SearchingPulse> createState() => _SearchingPulseState();
}

class _SearchingPulseState extends State<_SearchingPulse> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl; // drives radial pulse (0..1)
  late final AnimationController _orbitCtrl; // drives dot rotation (0..1)

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Use AnimatedBuilder to repaint CustomPaint when animations tick
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _orbitCtrl]),
      builder: (context, _) {
        return CustomPaint(
          painter: _PulsePainter(
            pulseT: _pulseCtrl.value,
            orbitT: _orbitCtrl.value,
            ringColor: cs.primary.withOpacity(0.25),
            orbitDotColor: cs.primary,
          ),
          child: Center(
            child: Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  // subtle glow that works in dark and light modes
                  BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 16, spreadRadius: 2),
                ],
              ),
              child: Icon(widget.icon, color: cs.onPrimaryContainer, size: 32),
            ),
          ),
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double pulseT; // 0..1 for pulse expansion
  final double orbitT; // 0..1 for rotation angle
  final Color ringColor;
  final Color orbitDotColor;

  _PulsePainter({required this.pulseT, required this.orbitT, required this.ringColor, required this.orbitDotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2; // keep rings within the box

    final paintRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ringColor;

    // Draw 3 expanding rings with staggered phases for a continuous wave effect
    for (int i = 0; i < 3; i++) {
      final phase = (pulseT + i / 3) % 1.0;
      final r = ui.lerpDouble(24, maxR, phase)!; // ring radius from near center to edge
      final alpha = (1 - phase) * 0.8; // fade out as it expands
      paintRing.color = ringColor.withOpacity(alpha.clamp(0, 1));
      canvas.drawCircle(center, r, paintRing);
    }

    // Orbiting dots around a mid-radius circle to imply searching
    final orbitR = maxR * 0.7;
    final dotPaint = Paint()..color = orbitDotColor;
    const dotCount = 4;
    for (int i = 0; i < dotCount; i++) {
      final angle = (orbitT + i / dotCount) * 2 * 3.1415926535; // radians
      final dx = center.dx + orbitR * MathCos(angle);
      final dy = center.dy + orbitR * MathSin(angle);
      canvas.drawCircle(Offset(dx, dy), 4, dotPaint);
    }
  }

  // Inline fast approximations for cos/sin to avoid importing dart:math repeatedly in paint
  double MathSin(double x) => math.sin(x);
  double MathCos(double x) => math.cos(x);

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.pulseT != pulseT || oldDelegate.orbitT != orbitT ||
        oldDelegate.ringColor != ringColor || oldDelegate.orbitDotColor != orbitDotColor;
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
