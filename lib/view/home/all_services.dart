import 'package:flutter/material.dart';

/// Modern Services screen
/// - SliverAppBar with large title + subtle search bar
/// - Horizontal "Popular" carousel with gradient text overlay
/// - Filter chips (All / Popular / Trending / Nearby)
/// - Animated grid of services (2 cols) with soft cards
/// - Everything pulls styling from your app Theme
class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<AllServicesScreen> {
  final TextEditingController _search = TextEditingController();

  /// You can replace icons with your asset images if you prefer.
  final List<_Service> _all = const [
    _Service('Home Cleaning', Icons.cleaning_services),
    _Service('Handyman', Icons.handyman),
    _Service('Plumbing', Icons.plumbing),
    _Service('Electrical', Icons.electrical_services),
    _Service('Interior Design', Icons.weekend),
    _Service('Painting', Icons.format_paint),
    _Service('Moving', Icons.local_shipping),
    _Service('Furniture Assembly', Icons.chair_alt),
    _Service('Smart Home Installation', Icons.device_hub),
    _Service('Appliance Repair', Icons.build_circle),
    _Service('Landscaping', Icons.yard),
    _Service('Pest Control', Icons.bug_report),
  ];

  final List<_Service> _popular = const [
    _Service('Interior Design', Icons.weekend),
    _Service('Home Cleaning', Icons.cleaning_services),
    _Service('Plumbing', Icons.plumbing),
  ];

  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;

    final filtered = _all.where((s) {
      final q = _search.text.trim().toLowerCase();
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      switch (_activeFilter) {
        case 'Popular':
          return _popular.any((p) => p.name == s.name);
        case 'Trending':
        // placeholder rule; plug your analytics here
          return ['Painting', 'Electrical', 'Plumbing'].contains(s.name);
        case 'Nearby':
        // placeholder rule; plug your location logic here
          return ['Home Cleaning', 'Handyman', 'Pest Control'].contains(s.name);
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 120,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Services',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: onBg,
              ),
            ),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchField(controller: _search, onChanged: (_) {
                  setState(() {});
                }),
              ),
            ),
          ),

          // Popular carousel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader(title: 'Popular', action: 'See more', onTap: () {
                setState(() => _activeFilter = 'Popular');
              }),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _popular.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = _popular[i];
                  return _PopularCard(service: p);
                },
              ),
            ),
          ),

          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final f in const ['All', 'Popular', 'Trending', 'Nearby'])
                    _FilterChip(
                      label: f,
                      selected: _activeFilter == f,
                      onSelected: () => setState(() => _activeFilter = f),
                    ),
                ],
              ),
            ),
          ),

          // All services grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _GridHeader(title: 'All Services', count: filtered.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            sliver: SliverAnimatedListGrid(
              items: filtered,
              builder: (context, s) => _ServiceCard(service: s, onTap: () {
                // TODO: Navigate to category listing or create request flow
                // Navigator.push(context, ...);
              }),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// ---------- UI Pieces ----------

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _SearchField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search services...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const _SectionHeader({required this.title, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onBackground;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: onBg,
            )),
        if (action != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Text(action!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ),
      ],
    );
  }
}

class _PopularCard extends StatelessWidget {
  final _Service service;
  const _PopularCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.06),
            )
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.primary.withOpacity(.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Big icon as decorative background
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Icon(
                  service.icon,
                  size: 72,
                  color: theme.colorScheme.primary.withOpacity(.15),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridHeader extends StatelessWidget {
  final String title;
  final int count;
  const _GridHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onBackground;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: onBg,
            )),
        Text('$count results',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final _Service service;
  final VoidCallback onTap;
  const _ServiceCard({required this.service, required this.onTap});

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(.15),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(0.04),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.service.icon, size: 30,
                      color: theme.colorScheme.primary),
                  const SizedBox(height: 10),
                  Text(
                    widget.service.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated grid that fades + slides items in a 2-column layout.
class SliverAnimatedListGrid extends StatelessWidget {
  final List<_Service> items;
  final Widget Function(BuildContext, _Service) builder;

  const SliverAnimatedListGrid({
    super.key,
    required this.items,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              // Staggered entrance animation
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 250 + (index * 30)),
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 10),
                    child: child,
                  ),
                ),
                child: builder(context, items[index]),
              );
            },
            childCount: items.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: .98,
          ),
        );
      },
    );
  }
}

/// ---------- Models ----------
class _Service {
  final String name;
  final IconData icon;
  const _Service(this.name, this.icon);
}