import 'package:flutter/material.dart';

import '../../model/provider_model.dart';



class ProviderSection extends StatefulWidget {
  const ProviderSection({super.key});

  @override
  State<ProviderSection> createState() => _ProviderSectionState();
}

class ProviderCard extends StatelessWidget {
  final ProviderInfoModel p;
  const ProviderCard({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final double iconSize = 52;
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x1A000000)),
        ],
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: iconSize,
              height: iconSize,
              child: (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                  ? Image.network(p.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.person, size: 32),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  p.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(p.rating.toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 6),
                    Text('(${p.reviews} reviews)', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R${p.ratePerHour.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text('/hour', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderSectionState extends State<ProviderSection> {
  final List<ProviderInfoModel> _providers = [
    ProviderInfoModel(
      name: 'Lerato M.',
      username: 'lerato_m',
      category: 'Home Cleaning',
      rating: 4.8,
      reviews: 126,
      ratePerHour: 180,
      imageUrl: 'https://picsum.photos/seed/cleaner/200/200',
    ),
    ProviderInfoModel(
      name: 'Sipho K.',
      username: 'sipho.k',
      category: 'Electrician',
      rating: 4.6,
      reviews: 98,
      ratePerHour: 250,
      imageUrl: 'https://picsum.photos/seed/electric/200/200',
    ),
    ProviderInfoModel(
      name: 'Anika R.',
      username: 'anika_r',
      category: 'Plumbing',
      rating: 4.9,
      reviews: 203,
      ratePerHour: 300,
      imageUrl: 'https://picsum.photos/seed/plumber/200/200',
    ),
    ProviderInfoModel(
      name: 'Thabo N.',
      username: 'thabo.n',
      category: 'Gardening',
      rating: 4.7,
      reviews: 77,
      ratePerHour: 160,
      imageUrl: 'https://picsum.photos/seed/garden/200/200',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Text(
                  'Top Rated Providers',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700
                  ),
                )
            ),
            TextButton(
                onPressed: () => {},
                child: Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 16,
                    // decoration: TextDecoration.underline,
                    decorationColor: Theme.of(context).colorScheme.primary,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
            )
          ],
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 4),
            itemCount: _providers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = _providers[index];
              return ProviderCard(p: p);
            },
          ),
        ),
      ],
    );
  }
}
