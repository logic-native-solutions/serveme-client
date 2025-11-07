import 'dart:async';
import 'package:flutter/material.dart';
import 'package:client/api/paystack_api.dart';
import 'package:client/api/stripe_connect_api.dart' show StripeStatus; // reuse model type only
import 'package:dio/dio.dart';

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
class ProviderPayoutsScreen extends StatefulWidget {
  const ProviderPayoutsScreen({super.key});

  static const String route = '/provider/payouts';

  @override
  State<ProviderPayoutsScreen> createState() => _ProviderPayoutsScreenState();
}

class _ProviderPayoutsScreenState extends State<ProviderPayoutsScreen> {
  StripeStatus? _status; // Reused model for Paystack status (linked + subaccountCode)
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final status = await PaystackApi.I.getPaystackStatus();
      if (!mounted) return;
      setState(() { _status = status; });
    } on TimeoutException {
      if (!mounted) return;
      setState(() { _error = 'Paystack status request timed out — pull to refresh.'; });
    } on DioException catch (e) {
      final data = e.response?.data;
      String? serverMsg;
      if (data is Map) { serverMsg = (data['message'] ?? data['error'] ?? data['detail'])?.toString(); }
      setState(() { _error = serverMsg ?? 'Failed to load Paystack status'; });
    } catch (_) {
      setState(() { _error = 'Failed to load Paystack status'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _formatMinor(int minor, String currency) {
    final code = currency.toUpperCase();
    return '$code ${(minor/100.0).toStringAsFixed(2)}';
  }


  String _date(int epoch) {
    if (epoch <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true).toLocal();
    String two(int v)=> v.toString().padLeft(2,'0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

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
              // Payouts Status ------------------------------------------------------
              Text(
                'Payouts Status',
                style: text.titleLarge?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _status != null
                    ? (_status!.linked
                        ? 'Linked${_status!.accountId != null ? ' (Subaccount: ${_status!.accountId})' : ''}'
                        : 'Not linked')
                    : (_loading ? 'Loading…' : (_error ?? '—')),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long_outlined, color: cs.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error ?? (_loading
                                  ? 'Loading…'
                                  : 'Transactions will appear here once payouts are processed. Complete Paystack onboarding if you haven\'t linked a subaccount.'),
                              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _load,
                          child: const Text('Refresh'),
                        ),
                      ),
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
