import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/api/paystack_api.dart';
import 'package:client/service/paystack_sdk.dart';
import 'package:client/view/home/current_user.dart';

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
class ManagePaymentMethodsScreen extends StatefulWidget {
  const ManagePaymentMethodsScreen({super.key});

  static const String route = '/provider/payouts/methods';

  @override
  State<ManagePaymentMethodsScreen> createState() => _ManagePaymentMethodsScreenState();
}

class _ManagePaymentMethodsScreenState extends State<ManagePaymentMethodsScreen> with WidgetsBindingObserver {
  bool _loading = false;
  String? _error;
  List<ProviderPaymentMethod> _methods = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer to next microtask to allow CurrentUserStore to initialize if needed
    scheduleMicrotask(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onResumeCheck();
    }
  }

  Future<void> _onResumeCheck() async {
    // If we initiated a card link, verify session then reload methods.
    final ref = PaystackApi.lastCardLinkReference;
    if (ref == null || ref.isEmpty) {
      // Still reload to reflect any webhook-based changes
      unawaited(_load());
      return;
    }
    try {
      await PaystackApi.I.verifyPaymentSession(reference: ref);
    } catch (_) {
      // Non-fatal; proceed to reload list
    } finally {
      PaystackApi.lastCardLinkReference = null; // clear sticky state
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final user = CurrentUserStore.I.user;
    if (user == null || user.id.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final items = await PaystackApi.I.listProviderPaymentMethods(uid: user.id);
      if (!mounted) return;
      setState(() { _methods = items; });
    } catch (e) {
      if (!mounted) return;
      // Silent fallback to empty list to avoid noisy snackbars on auto-refresh
      // (e.g., right after starting Add Payment Method).
      setState(() { _methods = const []; });
      // Log for diagnostics without disrupting UX
      debugPrint('ManagePaymentMethodsScreen: refresh methods failed: $e');
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _startLinkCard() async {
    final user = CurrentUserStore.I.user;
    if (user == null || user.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in first.')));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final init = await PaystackApi.I.initProviderCardLink(
        uid: user.id,
        email: user.email.isNotEmpty ? user.email : null,
        amount: 0,
      );
      PaystackApi.lastCardLinkReference = init.reference;
      final url = Uri.tryParse(init.authorizationUrl);
      if (url == null) throw Exception('Invalid authorization URL');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open browser');
      }
      // Give webhook time; then refresh when user returns.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return to app after completing card link.')));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to start card link: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
      // Attempt refresh regardless to catch fast webhooks
      unawaited(_load());
    }
  }

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
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
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
              Text(
                'Linked Payment Methods',
                style: text.titleLarge?.copyWith(
                  fontFamily: 'AnonymousPro',
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Card(
                  elevation: 0,
                  color: cs.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_methods.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('No payment methods yet. Tap Add to link a card.'),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: _methods.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant),
                              itemBuilder: (context, index) {
                                final m = _methods[index];
                                final title = (m.brand ?? 'Card') + (m.last4 != null && m.last4!.isNotEmpty ? ' •••• ${m.last4}' : '');
                                final subtitle = [
                                  if (m.expMonth != null && m.expYear != null) 'Exp ${m.expMonth}/${m.expYear}',
                                  if (m.bank != null && m.bank!.isNotEmpty) m.bank!,
                                ].join(' • ');
                                return ListTile(
                                  leading: const _MethodIcon(type: _MethodType.card),
                                  title: Text(title, style: text.titleMedium),
                                  subtitle: Text(subtitle, style: text.bodySmall),
                                );
                              },
                            )),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final res = await Navigator.of(context).pushNamed(AddPaymentMethodScreen.route);
                          // Refresh list after returning from add flow
                          if (mounted) unawaited(_load());
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
  bool _loading = false;

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

  /// Starts the secure card-link flow for providers, mirroring the client flow.
  /// Tries in-app Paystack SDK with accessCode first; falls back to opening the
  /// authorizationUrl in the external browser. On success, pops this screen so
  /// the list can refresh on return.
  Future<void> _startSecureLinkFlow() async {
    final user = CurrentUserStore.I.user;
    if (user == null || user.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Initialize SDK if a public key is available.
      bool sdkReady = false;
      try {
        final pk = await PaystackApi.I.getPaystackPublicKey();
        if (pk != null && pk.isNotEmpty) {
          await PaystackSdkService.I.initOnce(pk);
          sdkReady = true;
        }
      } catch (_) {
        sdkReady = false;
      }

      // Ask server to create a tokenize-only session and return accessCode/URL.
      final init = await PaystackApi.I.initProviderCardLink(
        uid: user.id,
        email: user.email.isNotEmpty ? user.email : null,
        amount: 0,
      );
      // Remember reference for fallback verification after redirect
      PaystackApi.lastCardLinkReference = init.reference;

      if (sdkReady && (init.accessCode != null && init.accessCode!.isNotEmpty)) {
        final ok = await PaystackSdkService.I.checkoutWithAccessCode(
          context: context,
          accessCode: init.accessCode!,
          email: user.email,
        );
        if (ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card linked successfully.')),
          );
          Navigator.of(context).pop(true);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening secure card page...')),
          );
        }
        // Continue to open authorization URL fallback below.
      }

      // Fallback to authorization URL in a browser view.
      final url = Uri.tryParse(init.authorizationUrl);
      if (url == null) {
        throw Exception('Invalid authorization URL');
      }
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw Exception('Could not open browser');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete card linking, then return to the app.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start card link: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                  onPressed: _loading
                      ? null
                      : () async {
                          if (_bankSelected) {
                            // For Paystack ZA provider wallet we only support card linking for now.
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bank account coming soon. Please link a debit/credit card.')),
                            );
                            setState(() => _bankSelected = false);
                            return;
                          }
                          await _startSecureLinkFlow();
                        },
                  child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add Payment Method'),
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
