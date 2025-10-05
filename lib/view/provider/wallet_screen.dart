import 'package:flutter/material.dart';

/// ProviderWalletScreen
/// ---------------------
/// A provider-focused Wallet screen that mirrors the Client wallet navigation
/// pattern but exposes provider privileges:
///  • Withdraw Funds (primary)
///  • Manage Payment Methods (payout destinations)
///  • Recent transactions list
///
/// Notes
/// -----
/// - Styling follows the existing app theme (Material 3 + seeded ColorScheme)
///   and uses AnonymousPro for major figures/titles where applicable.
/// - All data is mocked. Clear TODOs indicate where to connect your backend.
/// - This screen is safe to use standalone via route, and is also hosted as a
///   tab inside ProviderDashboardScreen's bottom navigation.
class ProviderWalletScreen extends StatelessWidget {
  // NOTE: This screen mirrors the client's bank-card style for the balance area
  // to keep the app consistent across roles. The _BankLikeBalanceCard below
  // mimics a physical bank card (full-width, primary background, onPrimary text).
  const ProviderWalletScreen({super.key});

  static const String route = '/provider/wallet';

  // Mock balance & transactions — replace via repository/store
  final double _balance = 1250.00;
  final List<_Txn> _txns = const [
    _Txn(title: 'Service Payment', dateLabel: 'Sep 28, 2025', amount: 450.00),
    _Txn(title: 'Payout to Bank', dateLabel: 'Sep 22, 2025', amount: -500.00),
    _Txn(title: 'Service Payment', dateLabel: 'Sep 17, 2025', amount: 300.00),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Wallet',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Balance card redesigned to mimic a real bank card (parity with Client)
              // Uses primary background and onPrimary text like the client's bank card UI.
              _BankLikeBalanceCard(balance: _balance),

              const SizedBox(height: 16),

              // Quick Actions -----------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        // Primary action for providers: withdraw funds
                        Navigator.of(context).pushNamed('/provider/payouts/withdraw');
                      },
                      child: const Text('Withdraw Funds'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/provider/payouts/methods');
                      },
                      child: const Text('Payment Methods'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Transactions header ----------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Transactions',
                      style: text.titleLarge?.copyWith(
                        fontFamily: 'AnonymousPro',
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to the full payouts view which lists transactions
                      Navigator.of(context).pushNamed('/provider/payouts');
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                color: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _txns.length; i++) ...[
                      if (i != 0) Divider(height: 1, color: cs.outlineVariant),
                      _TxnRow(txn: _txns[i]),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Notes for backend wiring -----------------------------------------
              Text(
                'Notes',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Replace the mocked balance and transactions with your backend data.\n'
                'Suggested endpoints: /api/v1/provider/payouts/balance and /api/v1/provider/payouts/transactions.\n'
                'Use /api/v1/provider/payouts/withdraw for the primary action and\n'
                '/api/v1/provider/payouts/methods for managing payout accounts.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// One transaction row (provider flavor): service payments (+) and payouts (−)
class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});
  final _Txn txn;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final positive = txn.amount >= 0;
    final color = positive ? Colors.green : Colors.red;
    final prefix = positive ? '+' : '−';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      title: Text(txn.title, style: text.titleMedium),
      subtitle: Text(txn.dateLabel, style: text.bodySmall),
      trailing: Text(
        'R${txn.amount.abs().toStringAsFixed(2)}',
        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Txn {
  final String title;
  final String dateLabel; // preformatted label for the template
  final double amount; // +incoming (service payment), -outgoing (payout)
  const _Txn({required this.title, required this.dateLabel, required this.amount});
}


/// Bank-like balance card used to mirror the client's wallet card visuals.
/// Full-width, rounded 16, primary background, and onPrimary typography.
class _BankLikeBalanceCard extends StatelessWidget {
  const _BankLikeBalanceCard({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final on = cs.onPrimary;

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: brand/title and a decorative chip icon, similar to client
            Row(
              children: [
                Text(
                  'ServeMe Wallet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: on,
                    fontFamily: 'AnonymousPro',
                  ),
                ),
                const Spacer(),
                Icon(Icons.sim_card, color: on.withOpacity(0.9)),
              ],
            ),
            const Spacer(),

            // Label + large amount (tabular figures for nice alignment)
            Text(
              'Current Balance',
              style: theme.textTheme.labelLarge?.copyWith(color: on.withOpacity(0.9)),
            ),
            const SizedBox(height: 4),
            Text(
              'R${balance.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: on,
                fontWeight: FontWeight.w800,
                fontFamily: 'AnonymousPro',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),

            // Bottom row: placeholder holder + masked id (mirrors client style)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Provider Account',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: on.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '•••• PROV',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: on.withOpacity(0.95),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
