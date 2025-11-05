import 'package:flutter/material.dart';

/// Modern promo/advert section with theme-aware gradient, badge, and CTA.
/// - Keeps existing background asset but overlays a branded gradient derived
///   from the current color scheme to look great in light and dark mode.
/// - Adds a small pill badge and a primary CTA button to improve visual appeal.
class AdvertSection extends StatelessWidget {
  const AdvertSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onImg = Colors.white; // text on top of image; good contrast in both modes with gradient

    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        image: const DecorationImage(
          image: AssetImage('assets/images/cleaning_ad.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(0.65), // brand tint
              Colors.black.withOpacity(0.55),   // depth
              scheme.primaryContainer.withOpacity(0.55),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: onImg.withOpacity(0.20),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: onImg.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, color: onImg, size: 16),
                  const SizedBox(width: 6),
                  Text('Limited time', style: TextStyle(color: onImg, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Special Offer',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: onImg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Get 20% off your first booking today.',
              style: TextStyle(
                fontSize: 14,
                color: onImg.withOpacity(0.90),
              ),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.secondary, foregroundColor: scheme.onSecondary),
              onPressed: () => Navigator.pushNamed(context, '/all-services'),
              child: const Text('Explore services'),
            ),
          ],
        ),
      ),
    );
  }
}