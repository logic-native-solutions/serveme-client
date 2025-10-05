import 'package:flutter/material.dart';

/// WithdrawFundsScreen
/// --------------------
/// Template for the withdraw flow: shows current balance, an amount input,
/// and a selectable payout method with a trailing switch (to mimic the
/// provided design). This is a UI-only template ready to be wired to backend.
///
/// Backend wiring guidance
/// - Prefill balance from GET /api/v1/provider/payouts/balance
/// - Load payout methods from GET /api/v1/provider/payouts/methods
/// - On submit, POST /api/v1/provider/payouts/withdraw { amount, destinationId }
class WithdrawFundsScreen extends StatefulWidget {
  const WithdrawFundsScreen({super.key});
  static const String route = '/provider/payouts/withdraw';

  @override
  State<WithdrawFundsScreen> createState() => _WithdrawFundsScreenState();
}

class _WithdrawFundsScreenState extends State<WithdrawFundsScreen> {
  // Mocked data for the template
  final double _balance = 1250.00;
  final List<_WithdrawMethod> _methods = const [
    _WithdrawMethod(id: 'pm_visa_4242', label: 'Visa', subtitle: 'Ending in 4242', icon: Icons.credit_card),
  ];

  String? _selectedMethodId; // which method is chosen
  final TextEditingController _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        centerTitle: false,
        title: const Text('Withdraw Funds'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Balance', style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)), 
              const SizedBox(height: 8),
              Text('R${_balance.toStringAsFixed(2)}', style: text.displaySmall?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
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
                child: Column(
                  children: _methods.map((m) {
                    final selected = _selectedMethodId == m.id;
                    return SwitchListTile(
                      value: selected,
                      onChanged: (_) {
                        setState(() {
                          _selectedMethodId = selected ? null : m.id;
                        });
                      },
                      title: Row(
                        children: [
                          Icon(m.icon, size: 28),
                          const SizedBox(width: 12),
                          Text(m.label, style: text.titleMedium),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(left: 40.0),
                        child: Text(m.subtitle, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Basic client-side checks for the template
                    final amount = double.tryParse(_amountCtrl.text.trim());
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                      return;
                    }
                    if (_selectedMethodId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a payment method')));
                      return;
                    }
                    // TODO: POST to /payouts/withdraw then refresh balance
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal submitted (mock)')));
                    Navigator.of(context).maybePop();
                  },
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

class _WithdrawMethod {
  final String id; final String label; final String subtitle; final IconData icon;
  const _WithdrawMethod({required this.id, required this.label, required this.subtitle, required this.icon});
}
