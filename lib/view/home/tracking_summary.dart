import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../service/tracking_service.dart';

/// TrackingSummary
/// ----------------
/// Compact home-card showing a quick summary of the active provider's progress.
/// Visual refresh: gradient accent, icon capsule, and clearer CTA.
class TrackingSummary extends StatefulWidget {
  const TrackingSummary({super.key});

  @override
  State<TrackingSummary> createState() => _TrackingSummaryState();
}

class _TrackingSummaryState extends State<TrackingSummary> {
  @override
  void initState() {
    super.initState();
    // For MVP demo we bind to a mock job so the summary immediately shows motion.
    // Replace with a real jobId when wiring to backend jobs.
    TrackingService.I.bindToJob(jobId: 'demo-job-1', startFrom: const LatLng(-26.21, 28.05));
    TrackingService.I.addListener(_onTick);
  }

  @override
  void dispose() {
    TrackingService.I.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final distanceKm = TrackingService.I.distanceKm();
    final eta = TrackingService.I.eta();

    final distanceText = distanceKm == null ? '—' : '${distanceKm.toStringAsFixed(1)} km away';
    final etaText = eta == null ? '' : ' • ETA ~ ${_fmtDuration(eta)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // Subtle gradient background derived from scheme, looks good in dark mode
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface,
            scheme.primaryContainer.withOpacity(0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x14000000))],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status icon capsule
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.navigation_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Tracking',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  distanceText + etaText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pushNamed('/tracking'),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('View map'),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '$m mins';
  }
}
