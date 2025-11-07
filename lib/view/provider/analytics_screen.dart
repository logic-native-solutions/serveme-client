import 'package:flutter/material.dart';

/// ProviderAnalyticsScreen
/// ------------------------
/// A presentational template for Provider Performance Analytics.
/// Follows the app's existing theme (Material 3 + AnonymousPro for headings)
/// and mirrors the supplied design structure. All data is mocked for now with
/// clear TODOs on where to connect your backend later.
///
/// Sections implemented:
///  • AppBar: "Analytics"
///  • Performance Overview header
///  • Card: Earnings Trends (amount, last 30 days delta, sparkline + month ticks)
///  • Card: Job Completion Rate (percentage, delta, completed vs cancelled bars)
///  • Section: Customer Satisfaction (avg rating, stars, reviews count,
///           and breakdown bars 5→1)
///
/// Why template-only? Keeps this screen drop-in ready and non-blocking while
/// backend APIs are finalized. You can wire it to live data by replacing the
/// mock values, or by lifting them into a provider/state store.
class ProviderAnalyticsScreen extends StatelessWidget {
  const ProviderAnalyticsScreen({super.key});

  static const String route = '/provider/analytics';

  // --------------------------------------------------------------------------
  // Mock data — replace these with your store/API later
  // --------------------------------------------------------------------------
  final double _earnings30d = 1250.00; // total earnings in the period
  final double _earningsDelta = 0.15; // +15% vs previous 30d
  final List<double> _earningsSpark = const [
    0.6, 0.35, 0.55, 0.28, 0.52, 0.8, 0.32, 0.58, 0.26, 0.64, 0.42, 0.7
  ]; // normalized 0..1 values

  final double _completionRate = 0.95; // 95%
  final double _completionDelta = 0.05; // +5% last 30 days
  final int _completedCount = 57;
  final int _cancelledCount = 3;

  final double _avgRating = 4.8;
  final int _reviewsCount = 235;
  final Map<int, double> _ratingBreakdown = const {
    5: 0.70,
    4: 0.20,
    3: 0.05,
    2: 0.03,
    1: 0.02,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: false,
        title: const Text('Analytics'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Overview',
                style: text.titleLarge?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Earnings Trends card -------------------------------------------------
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earnings Trends', style: text.titleMedium?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700, color: cs.onSurface)), 
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R${_earnings30d.toStringAsFixed(0)}',
                          style: text.displaySmall?.copyWith(
                            fontFamily: 'AnonymousPro',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DeltaChip(delta: _earningsDelta, label: 'Last 30 Days'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: _Sparkline(values: _earningsSpark, lineColor: cs.primary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Jan'),
                        Text('Feb'),
                        Text('Mar'),
                        Text('Apr'),
                        Text('May'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Job Completion Rate card -------------------------------------------
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Job Completion Rate', style: text.titleMedium?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700, color: cs.onSurface)), 
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${(_completionRate * 100).toStringAsFixed(0)}%', style: text.displaySmall?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DeltaChip(delta: _completionDelta, label: 'Last 30 Days'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniBar(
                            label: 'Completed',
                            value: _completedCount.toDouble(),
                            color: Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniBar(
                            label: 'Cancelled',
                            value: _cancelledCount.toDouble(),
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Customer Satisfaction ----------------------------------------------
              Text(
                'Customer Satisfaction',
                style: text.titleLarge?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(_avgRating.toStringAsFixed(1), style: text.displaySmall?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(5, (i) {
                                final filled = i < _avgRating.round();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    filled ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 4),
                            Text('$_reviewsCount reviews', style: text.bodySmall),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...[5, 4, 3, 2, 1].map((score) {
                      final pct = _ratingBreakdown[score] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 20, child: Text('$score', style: text.bodySmall)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(width: 32, child: Text('${(pct * 100).toStringAsFixed(0)}%', style: text.bodySmall, textAlign: TextAlign.right)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Notes for backend wiring -------------------------------------------
              Text(
                'Notes',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'All figures shown here are placeholders. Replace with live data from your analytics endpoints. '
                'See Track_of the changes.md for suggested payloads and where to connect.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lightweight card container that matches the look of other provider cards.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// A small chip that shows +/− deltas with color semantics and a label.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta, required this.label});
  final double delta; // positive or negative fraction e.g., 0.15
  final String label;
  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final color = up ? Colors.green : Colors.red;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 18),
        const SizedBox(width: 2),
        Text(
          '+${(delta.abs() * 100).toStringAsFixed(0)}%',
          style: text.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}

/// A tiny bar used for the Completed/Cancelled visual.
class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.label, required this.value, required this.color});
  final String label;
  final double value; // raw count; used for the label only in this template
  final Color color;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: 0.72, // static fill for template
            minHeight: 12,
            color: color,
            backgroundColor: color.withOpacity(0.16),
          ),
        ),
        const SizedBox(height: 8),
        Text('$label • ${value.toStringAsFixed(0)}', style: text.bodySmall),
      ],
    );
  }
}

/// A very small sparkline painter for the earnings chart. Values must be in 0..1.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, this.lineColor});
  final List<double> values; // normalized values
  final Color? lineColor;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _SparkPainter(values: values, color: lineColor ?? cs.primary),
      child: Container(),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final path = Path();
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final dx = size.width / (values.length - 1);
    double x = 0;
    double y = size.height * (1 - values.first.clamp(0.0, 1.0));
    path.moveTo(x, y);

    for (int i = 1; i < values.length; i++) {
      x = i * dx;
      y = size.height * (1 - values[i].clamp(0.0, 1.0));
      path.lineTo(x, y);
    }

    // Draw stroke
    canvas.drawPath(path, stroke);

    // Fill under the curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
