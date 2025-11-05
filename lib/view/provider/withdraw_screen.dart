import 'dart:async';
import 'package:flutter/material.dart';
import 'package:client/api/paystack_api.dart';
import 'package:client/view/home/current_user.dart';

/// WithdrawFundsScreen
/// --------------------
/// Provider withdraw flow wired to backend:
///  • Loads real balance from Paystack subaccount snapshot
///  • Lists provider payment methods (card authorizations) for selection
///  • Creates a withdrawal request (queued for ops to fulfill)
class WithdrawFundsScreen extends StatefulWidget {
  const WithdrawFundsScreen({super.key});
  static const String route = '/provider/payouts/withdraw';

  @override
  State<WithdrawFundsScreen> createState() => _WithdrawFundsScreenState();
}

class _WithdrawFundsScreenState extends State<WithdrawFundsScreen> {
  bool _loading = false;
  String? _error;
  PaystackAccountSnapshot? _account;
  List<ProviderPaymentMethod> _methods = const [];
  String? _selectedMethodId;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_loadAll);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final user = CurrentUserStore.I.user;
    if (user == null || user.id.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    bool acctOk = false;
    bool methodsOk = false;

    // Load account snapshot (balance)
    try {
      final snap = await PaystackApi.I.getAccountSnapshot();
      if (!mounted) return;
      setState(() { _account = snap; });
      acctOk = true;
    } catch (_) {
      // Keep going; we will only show an error if both requests fail.
    }

    // Load payment methods
    try {
      final methods = await PaystackApi.I.listProviderPaymentMethods(uid: user.id);
      if (!mounted) return;
      setState(() {
        _methods = methods;
        // Preselect the first method if available
        if (_methods.isNotEmpty) _selectedMethodId = _methods.first.authorizationCode;
      });
      methodsOk = true;
    } catch (_) {
      // Treat load failure as empty state (non-fatal for withdraw UI)
      if (!mounted) return;
      setState(() { _methods = const []; });
    }

    if (!mounted) return;
    setState(() {
      // Only show an error banner if everything failed
      _error = (acctOk || methodsOk) ? null : 'Failed to load wallet. Pull to refresh.';
      _loading = false;
    });
  }

  int get _availableCents => _account?.balances.available ?? 0;
  String get _currency => _account?.balances.currency ?? 'ZAR';

  Future<void> _submit() async {
    final user = CurrentUserStore.I.user;
    if (user == null || user.id.isEmpty) return;
    final amtStr = _amountCtrl.text.trim();
    final amount = double.tryParse(amtStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final cents = (amount * 100).round();
    if (cents > _availableCents) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount exceeds available balance')));
      return;
    }
    if (_selectedMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a payment method')));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final id = await PaystackApi.I.createProviderWithdraw(
        uid: user.id,
        amount: cents,
        currency: _currency,
        paymentMethodId: _selectedMethodId!,
        note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Withdrawal submitted${id != null ? ' (#$id)' : ''}')));
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to submit withdrawal: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final availableMajor = (_availableCents / 100.0).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        centerTitle: false,
        title: const Text('Withdraw Funds'),
        actions: [
          IconButton(onPressed: _loading ? null : _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: _loading && _account == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text('Current Balance', style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Text('${_currency} $availableMajor', style: text.displaySmall?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (_account?.balances.note != null && _account!.balances.note!.isNotEmpty)
                      Text(_account!.balances.note!, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 16),

                    // Amount input field
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        filled: true,
                        fillColor: cs.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add a note (optional)',
                        filled: true,
                        fillColor: cs.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 22),
                    Text('Select Payment Method', style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 8),

                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: (_methods.isEmpty)
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('No linked cards yet. Add one under Payment Methods.')),
                                ],
                              ),
                            )
                          : Column(
                              children: _methods.map((m) {
                                final selected = _selectedMethodId == m.authorizationCode;
                                final label = (m.brand ?? 'Card') + (m.last4 != null && m.last4!.isNotEmpty ? ' •••• ${m.last4}' : '');
                                final subtitle = [
                                  if (m.expMonth != null && m.expYear != null) 'Exp ${m.expMonth}/${m.expYear}',
                                  if (m.bank != null && m.bank!.isNotEmpty) m.bank!,
                                ].join(' • ');
                                return SwitchListTile(
                                  value: selected,
                                  onChanged: (_) {
                                    setState(() {
                                      _selectedMethodId = selected ? null : m.authorizationCode;
                                    });
                                  },
                                  title: Row(
                                    children: [
                                      const Icon(Icons.credit_card, size: 28),
                                      const SizedBox(width: 12),
                                      Text(label, style: text.titleMedium),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(left: 40.0),
                                    child: Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: const Text('Withdraw'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
