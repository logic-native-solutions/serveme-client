import 'package:flutter/material.dart';
import 'package:client/api/services_api.dart';

/// Home → Services section (visual refresh)
/// - Modernized tiles with subtle gradient overlays and price hint.
/// - Theme-aware to look great in dark mode.
class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});

  // Map backend service IDs to asset images used in the home design.
  String? _assetForService(String id) {
    switch (id.toLowerCase()) {
      case 'cleaner':
      case 'home_cleaning':
      case 'cleaning':
        return 'assets/images/Cleaning_Cat.png';
      case 'plumber':
      case 'plumbing':
        return 'assets/images/Plumbing_Cat.png';
      case 'electrician':
      case 'electrical':
        return 'assets/images/Electrician_Cat.png';
      case 'gardener':
      case 'gardening':
        return 'assets/images/Gardening_Cat.png';
      case 'moving':
      case 'mover':
        return 'assets/images/Moving_Out_Cat.png';
      case 'painting':
      case 'painter':
        return 'assets/images/Painting_Cat.png';
      case 'smart_home':
      case 'smart_home_installation':
        return 'assets/images/Smart_Appliances_Cat.png';
      case 'pest_control':
        return 'assets/images/Pest_Control_Cat.png';
      default:
        return null; // fall back to initial letter avatar
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Services',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/all-services'),
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: Text(
                'View all',
                style: TextStyle(
                  fontSize: 16,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<ServiceDoc>>(
          future: ServicesApi.I.fetchServices(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Services unavailable',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            final items = snap.data!;
            final display = items.take(6).toList();
            return GridView.builder(
              itemCount: display.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final s = display[index];
                final asset = _assetForService(s.id);
                // Price hint removed per product request to avoid focus on pricing here.
                // final price = s.basePrice; // cents
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/all-services',
                      arguments: {'serviceTypeId': s.id},
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (asset != null)
                                Image.asset(asset, fit: BoxFit.cover)
                              else
                                Container(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  alignment: Alignment.center,
                                  child: Text(
                                    s.displayName.isNotEmpty ? s.displayName[0] : '?',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              // gradient overlay for readability
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.05),
                                        Colors.black.withOpacity(0.35),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Title overlay removed to avoid duplicate labels; keep caption below only.
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // subtle caption to keep grid aligned; title already on tile
                      Text(
                        s.displayName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
