import 'package:flutter/material.dart';

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});

  static final categories = [
    {"image": "assets/images/Cleaning_Cat.png", "label": "Cleaning"},
    {"image": "assets/images/Plumbing_Cat.png", "label": "Plumbing"},
    {"image": "assets/images/Electrician_Cat.png", "label": "Electrical"},
    {"image": "assets/images/Gardening_Cat.png", "label": "Gardening"},
    {"image": "assets/images/Moving_Out_Cat.png", "label": "Moving"},
    {"image": "assets/images/Painting_Cat.png", "label": "Painting"},
    {"image": "assets/images/Smart_Appliances_Cat.png", "label": "Smart Home"},
    {"image": "assets/images/Pest_Control_Cat.png", "label": "Pest Control"},
  ];

  @override
  Widget build(BuildContext context) {
    return  Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700
                  ),
                )
            ),
            TextButton(
                onPressed: () => {
                  Navigator.pushNamed(context, '/all-services')
                },
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
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: List.generate(6, (index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      categories[index]["image"] as String,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  categories[index]["label"] as String,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
