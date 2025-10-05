import 'package:flutter/material.dart';

/// ManagePaymentMethodsScreen
/// ---------------------------
/// Presentational screen for viewing and managing payout destinations
/// (e.g., bank accounts or debit cards). Mirrors the provided design while
/// following ServeMe's existing theme (Material 3, seeded ColorScheme) and
/// typography (AnonymousPro for major headings).
///
/// Notes & Backend wiring
/// - Replace the mocked `_methods` list with data from your backend.
///   Suggested endpoint: GET /api/v1/provider/payouts/methods
///   Each item can include: id, type: 'bank'|'card', label, subtitle,
///   last4/expiry for cards, bankName for bank accounts, isDefault.
/// - Tapping the edit icon should open a dedicated edit screen or bottom sheet.
/// - "Add Payment Method" navigates to [AddPaymentMethodScreen].
class ManagePaymentMethodsScreen extends StatelessWidget {
  const ManagePaymentMethodsScreen({super.key});

  static const String route = '/provider/payouts/methods';

  // Mocked list of methods — replace with store/API.
  final List<_Method> _methods = const [
    _Method(id: 'm1', type: _MethodType.bank, label: 'Checking Account', subtitle: 'Bank of America'),
    _Method(id: 'm2', type: _MethodType.card, label: 'Debit Card', subtitle: 'Expires 08/2026'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: false,
        title: const Text('Manage Payment Methods'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Linked Payment Methods',
                style: text.titleLarge?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Methods list
              Expanded(
                child: Card(
                  elevation: 0,
                  color: cs.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _methods.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant),
                    itemBuilder: (context, index) {
                      final m = _methods[index];
                      return ListTile(
                        leading: _MethodIcon(type: m.type),
                        title: Text(m.label, style: text.titleMedium),
                        subtitle: Text(m.subtitle, style: text.bodySmall),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            // TODO: Navigate to an edit screen or open a sheet
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Edit method placeholder')), 
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Add Payment Method button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AddPaymentMethodScreen.route);
                  },
                  child: const Text('Add Payment Method'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodIcon extends StatelessWidget {
  const _MethodIcon({required this.type});
  final _MethodType type;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        type == _MethodType.bank ? Icons.account_balance_rounded : Icons.credit_card,
        color: cs.onSurface,
      ),
    );
  }
}

enum _MethodType { bank, card }

class _Method {
  final String id;
  final _MethodType type;
  final String label;
  final String subtitle;
  const _Method({required this.id, required this.type, required this.label, required this.subtitle});
}

/// AddPaymentMethodScreen
/// ----------------------
/// Form to register a new payout destination. Two tabs: Bank Account and
/// Debit Card, matching the design. Validation is intentionally minimal in this
/// template; wire up real validation and API calls during integration.
class AddPaymentMethodScreen extends StatefulWidget {
  const AddPaymentMethodScreen({super.key});
  static const String route = '/provider/payouts/methods/add';

  @override
  State<AddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends State<AddPaymentMethodScreen> {
  bool _bankSelected = true; // toggle between Bank Account and Debit Card

  // Simple controllers; in production consider a form package or validators
  final _holderCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _routingCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  final _cardNumberCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _routingCtrl.dispose();
    _bankNameCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: false,
        title: const Text('Add Payment Method'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Method', style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ChoiceChip(
                    label: 'Bank Account',
                    selected: _bankSelected,
                    onSelected: () => setState(() => _bankSelected = true),
                  ),
                  const SizedBox(width: 10),
                  _ChoiceChip(
                    label: 'Debit Card',
                    selected: !_bankSelected,
                    onSelected: () => setState(() => _bankSelected = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_bankSelected) ...[
                _Field(controller: _holderCtrl, hint: 'Account Holder Name'),
                const SizedBox(height: 12),
                _Field(controller: _accountCtrl, hint: 'Account Number', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _Field(controller: _routingCtrl, hint: 'Routing Number', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _Field(controller: _bankNameCtrl, hint: 'Bank Name'),
              ] else ...[
                _Field(controller: _cardNumberCtrl, hint: 'Card Number', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _Field(controller: _expCtrl, hint: 'Expiry (MM/YY)', keyboardType: TextInputType.datetime),
                const SizedBox(height: 12),
                _Field(controller: _cvvCtrl, hint: 'CVV', keyboardType: TextInputType.number, obscureText: true),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // TODO: Validate and POST to /api/v1/provider/payouts/methods
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment method added (mock)')),
                    );
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Add Payment Method'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.selected, required this.onSelected});
  final String label; final bool selected; final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surface,
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, this.keyboardType, this.obscureText = false});
  final TextEditingController controller; final String hint; final TextInputType? keyboardType; final bool obscureText;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
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
    );
  }
}
