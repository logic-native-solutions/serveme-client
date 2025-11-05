import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help Center
///
/// Provides FAQs with search, quick contact options, and a lightweight
/// placeholder for support tickets. Designed to match the current theme and
/// adapt to dark mode automatically.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  // Simple in-app FAQ dataset for MVP. These can be fetched from backend later.
  final List<_Faq> _faqs = const [
    _Faq('How do I book a provider?', 'Go to Services, choose a category, pick a provider, and tap Book.'),
    _Faq('How do I reschedule a booking?', 'Open the booking details and choose Reschedule to select a new time.'),
    _Faq('How do I contact support?', 'Use Chat Support in this screen, or email us anytime.'),
    _Faq('How do payouts work (providers)?', 'Payouts are processed to your linked method. See Provider > Payouts.'),
    _Faq('Why am I not receiving notifications?', 'Check Notifications settings and ensure push permissions are enabled.'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _filteredFaqs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search field
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search FAQs',
            ),
          ),
          const SizedBox(height: 16),

          // Quick contact actions
          _SectionHeader('Contact us'),
          Row(
            children: [
              Expanded(child: _ActionChip(
                icon: Icons.chat_bubble_outline,
                label: 'Chat Support',
                onTap: () {
                  // For MVP, open mailto. Later replace with in-app chat.
                  _openUrl('mailto:support@serveme.app?subject=Help%20request');
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _ActionChip(
                icon: Icons.email_outlined,
                label: 'Email',
                onTap: () => _openUrl('mailto:support@serveme.app'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _ActionChip(
                icon: Icons.call_outlined,
                label: 'Call',
                onTap: () => _openUrl('tel:+1234567890'),
              )),
            ],
          ),

          const SizedBox(height: 16),
          _SectionHeader('FAQs'),
          ...results.map((f) => _FaqTile(faq: f)).toList(),

          const SizedBox(height: 16),
          _SectionHeader('Recent tickets'),
          _TicketPlaceholder(scheme: scheme),

          const SizedBox(height: 24),
          Text(
            'Can’t find what you’re looking for? Reach us via chat or email and we’ll get to you shortly.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<_Faq> _filteredFaqs() {
    if (_query.isEmpty) return _faqs;
    final q = _query.toLowerCase();
    return _faqs
        .where((f) => f.q.toLowerCase().contains(q) || f.a.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        // Use a Row that can shrink and ellipsize text to avoid RenderFlex overflow
        // when the available width is tight (e.g., small devices or large text scale).
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}

class _FaqTile extends StatelessWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.help_outline, color: scheme.primary),
          title: Text(faq.q),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.a,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// Placeholder list for tickets until backend is wired.
class _TicketPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  const _TicketPlaceholder({required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: const [
          ListTile(
            leading: Icon(Icons.confirmation_number_outlined),
            title: Text('#1024 • Payment not reflected'),
            subtitle: Text('Open • Last updated 2h ago'),
            trailing: Icon(Icons.chevron_right),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.confirmation_number_outlined),
            title: Text('#1023 • Cannot verify phone'),
            subtitle: Text('Resolved • Yesterday'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
