import 'package:flutter/material.dart';

// This file intentionally keeps only the payout list view. See:
//  • withdraw_screen.dart for the Withdraw flow template
//  • manage_payment_methods_screen.dart for method management and add flow

/// ProviderPayoutsScreen
/// ----------------------
/// Presentational template for a provider to view current balance,
/// recent transactions, and access payout actions.
///
/// Design intent
///  - Mirrors the uploaded design structure (title, balance, recent list,
///    primary Withdraw button, secondary Manage Payment Methods button).
///  - Uses existing app theming (Material 3 + seeded ColorScheme) and the
///    AnonymousPro font for section headings and big numbers to match style.
///  - All data is mocked for now with clear TODOs on where to connect backend.
///
/// Backend wiring guidance
///  - GET  /api/v1/provider/payouts/balance → { balance: number }
///  - GET  /api/v1/provider/payouts/transactions?limit=20 →
///       [ { id, type:"service_payment"|"payout"|..., amount: number, createdAt: ISO8601 } ]
///  - POST /api/v1/provider/payouts/withdraw { amount, destinationId }
///  - GET  /api/v1/provider/payouts/methods → payout destinations list
///  - POST /api/v1/provider/payouts/methods (create/update)
///
/// Notes
///  - Replace the mock list below with your repository/store when APIs are ready.
///  - Amount prefix uses 'R' for Rand as used elsewhere; localize as needed.
class ProviderPayoutsScreen extends StatelessWidget {
  const ProviderPayoutsScreen({super.key});

  static const String route = '/provider/payouts';

  // Mock values — replace via state/store
  final double _balance = 1250.00;
  final List<_Txn> _txns = const [
    _Txn(title: 'Service Payment', dateLabel: 'August 15, 2024', amount: 250.00),
    _Txn(title: 'Service Payment', dateLabel: 'August 10, 2024', amount: 500.00),
    _Txn(title: 'Service Payment', dateLabel: 'August 5, 2024', amount: 500.00),
  ];

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
        title: const Text('Payouts'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Balance -----------------------------------------------------
              Text(
                'Current Balance',
                style: text.titleLarge?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'R${_balance.toStringAsFixed(2)}',
                style: text.displaySmall?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 24),

              // Recent Transactions ------------------------------------------------
              Text(
                'Recent Transactions',
                style: text.titleLarge?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              Card(
                elevation: 0,
                color: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    children: [
                      for (int i = 0; i < _txns.length; i++) ...[
                        if (i != 0) Divider(height: 1, color: cs.outlineVariant),
                        _TxnRow(txn: _txns[i]),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Withdraw Funds button ---------------------------------------------
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Open the withdraw flow template
                    Navigator.of(context).pushNamed('/provider/payouts/withdraw');
                  },
                  child: const Text('Withdraw Funds'),
                ),
              ),

              const SizedBox(height: 12),

              // Manage Payment Methods button -------------------------------------
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/provider/payouts/methods');
                  },
                  child: const Text('Manage Payment Methods'),
                ),
              ),

              const SizedBox(height: 12),

              // Small hint about payout cadence / processing times
              Text(
                'Note: Payouts may take 1–2 business days to reach your bank depending on the method.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// One transaction row showing title + date on the left and amount on the right.
class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});
  final _Txn txn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      title: Text(txn.title, style: text.titleMedium),
      subtitle: Text(txn.dateLabel, style: text.bodySmall),
      trailing: Text(
        '+R${txn.amount.toStringAsFixed(2)}',
        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Tiny immutable model for the mocked transaction list
class _Txn {
  final String title;
  final String dateLabel; // Preformatted for the template
  final double amount;
  const _Txn({required this.title, required this.dateLabel, required this.amount});
}
