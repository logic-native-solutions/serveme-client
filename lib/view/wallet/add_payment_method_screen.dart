import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/api/paystack_api.dart';
import 'package:client/service/paystack_sdk.dart';
import 'package:client/view/home/current_user.dart';

/// AddPaymentMethodScreen (Client)
/// --------------------------------
/// UI-only card entry form inspired by the provided design. For security,
/// we do not handle raw PAN data on-device. The Add button triggers the
/// existing, secure Paystack SDK/redirect flow to tokenize the card.
///
/// Notes
/// - The text fields are intentionally NOT read to construct a charge; they
///   are placeholders to match the UX while Paystack provides the secure
///   entry. This avoids handling PCI-sensitive data.
/// - We reuse the same server endpoints used by ClientPaymentMethodsScreen.
class ClientAddPaymentMethodScreen extends StatefulWidget {
  const ClientAddPaymentMethodScreen({super.key});
  static const String route = '/client/payment-methods/add';

  @override
  State<ClientAddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends State<ClientAddPaymentMethodScreen> {
  final _cardCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _cardCtrl.dispose();
    _expCtrl.dispose();
    _cvcCtrl.dispose();
    super.dispose();
  }

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
      // Best effort: make sure a Paystack customer exists.
      try {
        await PaystackApi.I.createClientCustomer(
          uid: user.id,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          phone: user.phoneNumber,
        );
      } catch (_) {
        // Non-fatal; backend can upsert later.
      }

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
      final init = await PaystackApi.I.initClientCardLink(
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
            const SnackBar(content: Text('Card added. You can manage it under Payment Methods.')),
          );
          Navigator.of(context).pop(true);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening secure card screen...')),
          );
        }
        // Do not return; continue to open authorization URL fallback below.
      }

      // Fallback to authorization URL in a browser view.
      final url = Uri.tryParse(init.authorizationUrl);
      if (url == null) {
        throw StateError('Invalid authorization URL');
      }
      try {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete the secure card screen, then return here.')),
        );
      }
      // Close this screen; the list page supports pull-to-refresh and polling.
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add payment method'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('New card', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          // Card number
          // SA cards (Visa/Mastercard) typically use 16-digit PAN. We limit to 16 digits here.
          _RoundedField(
            controller: _cardCtrl,
            hint: 'Card number',
            icon: Icons.credit_card,
            keyboardType: TextInputType.number,
            maxLength: 16,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _RoundedField(
                  controller: _expCtrl,
                  hint: 'Expiry (MM/YY)',
                  keyboardType: TextInputType.number,
                  // Allow only digits and a single slash, max 5 chars (MM/YY)
                  maxLength: 5,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[0-9/]")),
                    LengthLimitingTextInputFormatter(5),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoundedField(
                  controller: _cvcCtrl,
                  hint: 'Secure code',
                  keyboardType: TextInputType.number,
                  // CVV/CVC for SA Visa/Mastercard is 3 digits
                  maxLength: 3,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            'Your bank may place a small temporary hold to verify your card. This isn\'t a charge and will clear shortly.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),

          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _loading ? null : _startSecureLinkFlow,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: _loading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add card'),
            ),
          ),
        ],
      ),
    );
  }
}

// Hotfix: Removed accidental literal \n that broke parsing during hot-restart.
class _RoundedField extends StatelessWidget {
  const _RoundedField({
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
  });
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      buildCounter: (_, {required int currentLength, required bool isFocused, required int? maxLength}) => null, // hide counter UI
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const UnderlineInputBorder(),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
      ),
    );
  }
}

class _BrandDot extends StatelessWidget {
  const _BrandDot({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
