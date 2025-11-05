import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
// Added: access saved client cards to render under Manage your cards
import 'package:client/api/paystack_api.dart';
import 'package:client/view/home/current_user.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: _WalletScreen());
  }
}

class _WalletScreen extends StatefulWidget {
  const _WalletScreen();

  @override
  State<_WalletScreen> createState() => _WalletScreenState();
}

// Simple transactions filter
enum _TxFilter { all, inOnly, outOnly }

class _WalletScreenState extends State<_WalletScreen> {
  // Reload ticker to refresh the cards list FutureBuilder when actions complete
  int _reloadTick = 0;
  final PageController _cardsCtrl = PageController();
  int _cardIndex = 0;
  _TxFilter _filter = _TxFilter.all;

  bool _autoTopUp = false;

  // Mock cards & transactions — wire to your store/API later
  final List<_WalletCard> _cards = const [
    _WalletCard(
      brand: 'Visa',
      holder: 'Logic Native',
      last4: '1234',
      balance: 2350.75,
    ),
    _WalletCard(
      brand: 'Mastercard',
      holder: 'Operations',
      last4: '8821',
      balance: 510.10,
    ),
  ];

  final List<_Tx> _tx = const [
    _Tx(title: 'House Cleaning', subtitle: 'Yesterday · 10:40', amount: -350.0, icon: Icons.cleaning_services),
    _Tx(title: 'Top-up', subtitle: '2 days ago · EFT', amount: 500.0, icon: Icons.account_balance),
    _Tx(title: 'Plumbing Fix', subtitle: 'Sep 11 · 14:00', amount: -650.0, icon: Icons.plumbing),
    _Tx(title: 'Refund', subtitle: 'Sep 05 · Dispute', amount: 120.0, icon: Icons.replay),
    _Tx(title: 'Service Tip', subtitle: 'Aug 29 · Wallet', amount: -50.0, icon: Icons.volunteer_activism),
  ];

  Future<void> _onRefresh() async {
    // Refresh hook now also triggers a reload of saved cards shown below
    setState(() { _reloadTick++; });
    // TODO: hook to your repository refresh
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  List<_Tx> get _visibleTx {
    switch (_filter) {
      case _TxFilter.inOnly:
        return _tx.where((t) => t.amount > 0).toList();
      case _TxFilter.outOnly:
        return _tx.where((t) => t.amount < 0).toList();
      case _TxFilter.all:
      return _tx;
    }
  }

  @override
  void dispose() {
    _cardsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Page title (renamed to avoid confusion and duplication with lower actions)
          Text(
            'Payment methods',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),


          const SizedBox(height: 16),

          // Cards-only revamp: remove transaction history for client
          const SizedBox(height: 8),
          _CardsOnlyEmptyState(
            onAddCard: _onAddCard,
            onManage: _onManageCards,
          ),

          const SizedBox(height: 16),

          // Display saved cards stacked below the management panel
          _ClientCardsStack(reloadTick: _reloadTick),
        ],
      ),
    );
  }

  // Actions (wire these up to your flows)
  void _onAddFunds() {
    // TODO: navigate to Add Funds (amount -> method -> confirm)
  }

  void _onPay() {
    // TODO: navigate to Pay flow (QR scan / enter code / pick provider)
  }

  Future<void> _onManageCards() async {
    // Navigate to the client Payment Methods screen (list cards, set default, remove)
    final res = await Navigator.of(context).pushNamed('/client/payment-methods');
    // After returning, refresh the inline cards stack so users don't have to pull to refresh
    if (mounted) {
      setState(() { _reloadTick++; });
    }
  }

  Future<void> _onAddCard() async {
    // Opens the new Add Payment Method screen (client)
    final res = await Navigator.of(context).pushNamed('/client/payment-methods/add');
    // After returning from the add flow, refresh the inline cards stack to show newly linked card(s)
    if (mounted) {
      setState(() { _reloadTick++; });
    }
  }
}

// ---------- Components ----------

/// _ClientCardsStack
/// ------------------
/// Fetches the current client's saved cards and renders them as a neat
/// vertical stack of card widgets (brand + last4 + expiry). It is designed
/// to be lightweight and self-contained for the Wallet screen entry point.
class _ClientCardsStack extends StatefulWidget {
  const _ClientCardsStack({required this.reloadTick});
  final int reloadTick; // bump to force re-fetch

  @override
  State<_ClientCardsStack> createState() => _ClientCardsStackState();
}

class _ClientCardsStackState extends State<_ClientCardsStack> {
  late Future<List<ClientPaymentMethod>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _ClientCardsStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<List<ClientPaymentMethod>> _load() async {
    final user = CurrentUserStore.I.user;
    if (user == null || user.id.isEmpty) {
      return const [];
    }
    try {
      final items = await PaystackApi.I.listClientPaymentMethods(uid: user.id);
      return items;
    } catch (_) {
      // For the wallet entry, swallow errors and render a quiet empty state.
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder<List<ClientPaymentMethod>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              ),
            ),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          // No cards linked yet; keep UI minimal to avoid duplication with the panel above.
          return const SizedBox.shrink();
        }

        // Render visually appealing stacked cards
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Your cards',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ...items.map((m) => _ClientMiniCard(method: m)).toList(),
          ],
        );
      },
    );
  }
}

/// Compact, modern card widget used in the stack
class _ClientMiniCard extends StatelessWidget {
  const _ClientMiniCard({required this.method});
  final ClientPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brand = (method.brand?.isNotEmpty == true) ? method.brand! : 'Card';
    final last4 = method.last4 ?? '••••';
    final exp = _formatExp(method.expMonth, method.expYear);

    // Derive a consistent, brand-based gradient using theme colors so the card feels native.
    final gradient = _brandGradient(cs, brand: brand, seed: last4);

    // Compose a realistic credit card surface using an AspectRatio and layered decorations.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1.58, // Typical credit card ratio ~85.60mm × 53.98mm
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
              ),
              child: Stack(
                children: [
                  // Subtle radial highlight for modern look
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.onPrimary.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: brand label and contactless indicator
                        Row(
                          children: [
                            _BrandBadge(brand: brand, color: cs.onPrimary),
                            const Spacer(),
                            Icon(Icons.nfc, color: cs.onPrimary.withValues(alpha: 0.9), size: 20),
                          ],
                        ),
                        const Spacer(),
                        // Middle: simulated chip
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 26,
                              decoration: BoxDecoration(
                                color: cs.onPrimary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: cs.onPrimary.withValues(alpha: 0.28), width: 1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Card number (masked) using tabular figures for realism
                        Text(
                          _maskedNumber(last4),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Footer: Expiry and reusable badge
                        Row(
                          children: [
                            if (exp.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('VALID THRU', style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimary.withValues(alpha: 0.8), letterSpacing: 1.1)),
                                  const SizedBox(height: 2),
                                  Text(exp, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            const Spacer(),
                            if (method.reusable)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.onPrimary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: cs.onPrimary.withValues(alpha: 0.22)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: cs.onPrimary),
                                    const SizedBox(width: 6),
                                    Text('Reusable', style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
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

  // Format MM/YY nicely; returns '' if missing
  static String _formatExp(String? m, String? y) {
    final mm = m?.trim();
    final yy = y?.trim();
    if (mm == null || mm.isEmpty || yy == null || yy.isEmpty) return '';
    final mm2 = mm.padLeft(2, '0');
    final yy2 = yy.length == 4 ? yy.substring(2) : yy.padLeft(2, '0');
    return '$mm2/$yy2';
  }

  // Create a masked number like "••••  ••••  ••••  1234"
  static String _maskedNumber(String last4) {
    final l4 = last4.padLeft(4, '•');
    return '••••  ••••  ••••  $l4';
  }

  // Select a pleasing gradient based on brand/seed while respecting theme.
  // Updated: Always use the app's primary green for client cards to match the design direction.
  static Gradient _brandGradient(ColorScheme cs, {required String brand, required String seed}) {
    // We intentionally ignore brand/seed here to keep a consistent green look
    // across all cards, leveraging the app theme so dark mode stays correct.
    final c1 = cs.primary.withValues(alpha: 0.98);
    // Use primaryContainer as a softer companion for a modern gradient.
    final c2 = cs.primaryContainer.withValues(alpha: 0.90);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c1, c2],
    );
  }
}

// Small brand badge rendered on the card face to indicate network
class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.brand, required this.color});
  final String brand;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = brand.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
    );
  }
}

class _WalletCardView extends StatelessWidget {
  const _WalletCardView({required this.card});
  final _WalletCard card;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
        ),
        padding: const EdgeInsets.all(16),
        child: _CardFace(card: card),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card});
  final _WalletCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand + chip
        Row(
          children: [
            Text(
              card.brand,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: onPrimary,
              ),
            ),
            const Spacer(),
            Icon(Icons.sim_card, color: onPrimary.withValues(alpha: 0.9)),
          ],
        ),
        const Spacer(),
        // Balance
        Text(
          'Balance',
          style: theme.textTheme.labelLarge?.copyWith(color: onPrimary.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: 4),
        Text(
          _money(card.balance),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: onPrimary,
          ),
        ),
        const SizedBox(height: 16),
        // Holder / last4
        Row(
          children: [
            Expanded(
              child: Text(
                card.holder,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onPrimary.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '•••• ${card.last4}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onPrimary.withValues(alpha: 0.95),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardListTile extends StatelessWidget {
  const _CardListTile({required this.card});
  final _WalletCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.credit_card),
      ),
      title: Text('${card.brand} •••• ${card.last4}',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(card.holder, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      trailing: TextButton(
        onPressed: () {},
        child: const Text('Default'),
      ),
      onTap: () {
        // TODO: set default card or open manage card actions
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.card});
  final _WalletCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Available balance',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            _money(card.balance),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.t});
  final _Tx t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isIn = t.amount > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(t.icon, color: cs.onSurfaceVariant),
      ),
      title: Text(t.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(t.subtitle, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      trailing: Text(
        (isIn ? '+' : '') + _money(t.amount.abs()),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: isIn ? cs.tertiary : cs.error,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: () => _openTxDetails(context, t),
    );
  }

  void _openTxDetails(BuildContext context, _Tx t) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(t.icon, color: cs.onSurfaceVariant),
              ),
              title: Text(t.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(t.subtitle),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Amount', style: theme.textTheme.bodyMedium)),
                Text(_money(t.amount), style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Reference', style: theme.textTheme.bodyMedium)),
                Text('#${t.hashCode.toRadixString(16)}'.toUpperCase(), style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Invoice'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SafeArea(top: false, child: SizedBox(height: 4)),
          ],
        ),
      ),
    );
  }
}

class _CardsOnlyEmptyState extends StatelessWidget {
  const _CardsOnlyEmptyState({required this.onAddCard, required this.onManage});
  final VoidCallback onAddCard;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.credit_card, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manage your cards', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Link a debit/credit card to pay securely in-app. Remove cards any time.',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAddCard,
                  icon: const Icon(Icons.add_card),
                  label: const Text('Add card'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.credit_card_rounded),
                  label: const Text('Manage cards'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.cta,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          if (cta != null) ...[
            const SizedBox(height: 12),
            cta!,
          ],
        ],
      ),
    );
  }
}

// ---------- Models & helpers ----------

class _WalletCard {
  final String brand;    // Visa/Mastercard/etc
  final String holder;   // Card holder (display)
  final String last4;    // Last 4 digits
  final double balance;  // Current balance

  const _WalletCard({
    required this.brand,
    required this.holder,
    required this.last4,
    required this.balance,
  });
}

class _Tx {
  final String title;
  final String subtitle;
  final double amount; // +in / -out
  final IconData icon;

  const _Tx({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
  });
}

String _money(double v) {
  // South African Rand-style formatting (simple)
  // Replace with intl if you already use it.
  final s = v.abs().toStringAsFixed(2);
  return 'R$s';
}