import 'package:flutter/material.dart';

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
          // Page title
          Text(
            'Wallet',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // Banking cards carousel
          SizedBox(
            height: 190,
            child: PageView.builder(
              controller: _cardsCtrl,
              onPageChanged: (i) => setState(() => _cardIndex = i),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final c = _cards[index];
                return _WalletCardView(card: c);
              },
            ),
          ),
          const SizedBox(height: 8),

          // Page dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_cards.length, (i) {
              final selected = i == _cardIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: selected ? 20 : 8,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Add Funds + client quick actions (Pay, Cards)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _onAddFunds,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Funds'),
                ),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.qr_code_scanner,
                label: 'Pay',
                onTap: _onPay, // scan & pay or enter code
              ),
              const SizedBox(width: 8),
              _QuickAction(
                icon: Icons.credit_card,
                label: 'Cards',
                onTap: _onManageCards, // manage saved cards
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Balance summary row
          _BalanceSummary(card: _cards[_cardIndex]),

          const SizedBox(height: 16),

          // Payment Methods (client-focused)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment Methods',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _onAddCard,
                icon: const Icon(Icons.add_card),
                label: const Text('Add card'),
              ),
            ],
          ),
          ..._cards.map((c) => _CardListTile(card: c)),

          const SizedBox(height: 8),

          // Auto top-up toggle
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              value: _autoTopUp,
              onChanged: (v) => setState(() => _autoTopUp = v),
              title: const Text('Auto top-up'),
              subtitle: const Text('Keep a minimum balance for faster checkout'),
              secondary: const Icon(Icons.flash_auto),
            ),
          ),

          const SizedBox(height: 16),

          // Transaction header + filter
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SegmentedButton<_TxFilter>(
                segments: const [
                  ButtonSegment(value: _TxFilter.all, label: Text('All')),
                  ButtonSegment(value: _TxFilter.inOnly, label: Text('In')),
                  ButtonSegment(value: _TxFilter.outOnly, label: Text('Out')),
                ],
                selected: <_TxFilter>{_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (_visibleTx.isEmpty)
            _EmptyList(
              icon: Icons.receipt_long,
              title: 'No transactions yet',
              subtitle: 'Top up your wallet or make your first booking.',
              cta: TextButton.icon(
                onPressed: _onAddFunds,
                icon: const Icon(Icons.add_card),
                label: const Text('Add funds'),
              ),
            )
          else
            ..._visibleTx.map((t) => _TxTile(t: t)),
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

  void _onManageCards() {
    // TODO: navigate to Payment Methods screen (list cards, set default, remove)
  }

  void _onAddCard() {
    // TODO: show Add Card sheet (card number, expiry, cvc) or route to PSP
  }
}

// ---------- Components ----------

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