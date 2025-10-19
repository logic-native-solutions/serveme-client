import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:client/api/stripe_connect_api.dart';
import 'package:client/api/paystack_api.dart';
import 'package:dio/dio.dart';

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
class ProviderWalletScreen extends StatefulWidget {
  // NOTE: This screen mirrors the client's bank-card style for the balance area
  // to keep the app consistent across roles. The _BankLikeBalanceCard below
  // mimics a physical bank card (full-width, primary background, onPrimary text).
  const ProviderWalletScreen({super.key});

  static const String route = '/provider/wallet';

  @override
  State<ProviderWalletScreen> createState() => _ProviderWalletScreenState();
}

class _ProviderWalletScreenState extends State<ProviderWalletScreen> {
  // Live Stripe Connect snapshot and account info for the provider.
  StripeStatus? _stripe;
  StripeAccountInfo? _account; // includes balances and recent transactions
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Paystack: No balances endpoint in client spec; fetch linkage status only.
      final status = await PaystackApi.I.getPaystackStatus();
      if (!mounted) return;
      setState(() {
        _account = null; // balances not available via Paystack in this client template
        _stripe = status; // Reuse model for UI compatibility
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'Paystack status request timed out — pull to refresh.';
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mapDioError(e, fallback: 'Failed to load Paystack status');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mapDioError(e, fallback: 'Failed to load Paystack status');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Enhanced for Paystack upsert fix: surface helpful backend fields when present.
  // See: Features documents/paystack-upsert-fix.md
  String _mapDioError(Object e, {required String fallback}) {
    if (e is TimeoutException) return 'Request timed out — try again.';
    if (e is DioException) {
      final data = e.response?.data;
      String? msg;
      String? stage;
      String? upstreamMsg;
      if (data is Map) {
        msg = (data['message'] ?? data['error'] ?? data['detail'] ?? data['error_description'])?.toString();
        stage = data['stage']?.toString();
        final upstream = data['upstream'];
        if (upstream is Map) {
          upstreamMsg = (upstream['message'] ?? upstream['body'] ?? upstream['error'])?.toString();
        } else if (data['upstreamMessage'] != null) {
          upstreamMsg = data['upstreamMessage'].toString();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        msg = data.trim();
      }
      if ((msg == null || msg.isEmpty) && (stage != null || (upstreamMsg != null && upstreamMsg.isNotEmpty))) {
        msg = stage != null ? 'Failed at $stage: ${upstreamMsg ?? 'unexpected error'}' : upstreamMsg;
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'No internet connection — check network and try again.';
      }
      final code = e.response?.statusCode ?? 0;
      if (code == 401) return 'Your session expired — please log in again.';
      if (code == 403) return 'You do not have permission to view this.';
      if (code == 503) return 'Payouts service temporarily unavailable — try later.';
      if (code >= 500) return msg ?? 'Server error ($code) — try again shortly.';
      return msg ?? fallback;
    }
    return fallback;
  }

  // Returns a best-effort currency code from a list of StripeBalanceAmount entries.
  String _preferredCurrency(List<StripeBalanceAmount> list) {
    if (list.isNotEmpty && list.first.currency.isNotEmpty) return list.first.currency;
    return 'usd';
  }

  // Formats Stripe minor units (e.g., cents) into a simple string like "USD 12.34".
  String _formatMinor(int minor, String currency) {
    final code = currency.toUpperCase();
    final major = minor / 100.0;
    return '$code ${major.toStringAsFixed(2)}';
  }

  String _formatDate(int epochSeconds) {
    if (epochSeconds <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

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

              // Stripe connection status banner — uses live data from StripeConnectApi
              _StripeStatusBanner(
                loading: _loading,
                status: _stripe,
                error: _error,
                onRefresh: _refresh,
              ),

              const SizedBox(height: 12),

              // Balance card: show available balance from Stripe account info (sum of available amounts).
              _BankLikeBalanceCard(
                balanceLabel: _account != null
                    ? _formatMinor(_account!.balances.availableTotalMinor, _preferredCurrency(_account!.balances.available))
                    : null,
                balance: _account != null ? _account!.balances.availableTotalMinor / 100.0 : 0.0,
              ),

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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: (_account != null && _account!.transactions.isNotEmpty)
                      ? Column(
                          children: [
                            for (int i = 0; i < _account!.transactions.length; i++) ...[
                              if (i != 0) Divider(height: 1, color: cs.outlineVariant),
                              _StripeTxnRow(txn: _account!.transactions[i], formatter: _formatMinor, dateFormatter: _formatDate),
                            ],
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading ? null : _refresh,
                                child: const Text('Refresh'),
                              ),
                            )
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, color: cs.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                (_stripe?.linked == true)
                                    ? 'No transactions yet'
                                    : 'Add your Paystack payout details to start receiving payouts. No transactions yet.',
                                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                            TextButton(
                              onPressed: _loading ? null : _refresh,
                              child: const Text('Refresh'),
                            )
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // Notes for backend wiring -----------------------------------------
              // Text(
              //   'Notes',
              //   style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              // ),
              const SizedBox(height: 6),
              // Text(
              //   'Replace the mocked balance and transactions with your backend data.\n'
              //   'Suggested endpoints: /api/v1/provider/payouts/balance and /api/v1/provider/payouts/transactions.\n'
              //   'Use /api/v1/provider/payouts/withdraw for the primary action and\n'
              //   '/api/v1/provider/payouts/methods for managing payout accounts.',
              //   style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              // ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// One transaction row (provider flavor): service payments (+) and payouts (−)
class _StripeStatusBanner extends StatelessWidget {
  const _StripeStatusBanner({
    required this.loading,
    required this.status,
    required this.error,
    required this.onRefresh,
  });
  final bool loading;
  final StripeStatus? status;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final linked = status?.linked == true;
    final enabled = status?.payoutsEnabled == true;
    final acct = status?.accountId;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (loading) ...[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
            ] else ...[
              Icon(
                linked && enabled ? Icons.verified_rounded : Icons.account_balance_wallet_outlined,
                color: linked && enabled ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    linked && enabled
                        ? 'Payouts enabled'
                        : (linked ? 'Paystack payouts linked' : 'Add your Paystack payout details to receive payouts'),
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (acct != null && acct.isNotEmpty)
                    Text(
                      acct,
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(error!, style: text.bodySmall?.copyWith(color: cs.error)),
                  ],
                ],
              ),
            ),
            TextButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stripe transaction row bound to StripeBalanceTxn; formats amount (net preferred) and created date.
class _StripeTxnRow extends StatelessWidget {
  const _StripeTxnRow({required this.txn, required this.formatter, required this.dateFormatter});
  final StripeBalanceTxn txn;
  final String Function(int minor, String currency) formatter;
  final String Function(int epochSeconds) dateFormatter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final net = txn.net != 0 ? txn.net : txn.amount;
    final positive = net >= 0;
    final color = positive ? Colors.green : Colors.red;
    final title = (txn.description.isNotEmpty ? txn.description : txn.type).trim();
    final date = dateFormatter(txn.created);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      title: Text(title.isEmpty ? 'Transaction' : title, style: text.titleMedium),
      subtitle: Text(date, style: text.bodySmall),
      trailing: Text(
        (positive ? '+' : '−') + formatter(net.abs(), txn.currency),
        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// NOTE: Removed duplicate _StripeStatusBanner (second definition) to resolve
// a duplicate symbol error. The primary implementation appears earlier.

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
  const _BankLikeBalanceCard({required this.balance, this.balanceLabel});
  final double balance;
  final String? balanceLabel;

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
              'Available Balance',
              style: theme.textTheme.labelLarge?.copyWith(color: on.withOpacity(0.9)),
            ),
            const SizedBox(height: 4),
            Text(
              balanceLabel ?? 'R${balance.toStringAsFixed(2)}',
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
