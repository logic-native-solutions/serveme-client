import 'dart:async';
import 'package:client/api/paystack_api.dart';
import 'package:client/view/home/current_user.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/service/paystack_sdk.dart';

/// ClientPaymentMethodsScreen
/// --------------------------
/// Lets clients (payers) link a card via Paystack and view saved payment methods.
/// Adapts to the backend changes described in Features documents/client-paystack-onboarding.md
///
/// Key behaviors
/// - Loads current user from CurrentUserStore to obtain the uid (UserModel.id).
/// - Calls PaystackApi.listClientPaymentMethods to fetch saved methods under clients/{uid}/paymentMethods.
/// - "Link a card" triggers PaystackApi.initClientCardLink and opens the returned authorizationUrl.
/// - After returning to the app, users can pull-to-refresh to see the newly saved card
///   (the webhook persists it asynchronously).
class ClientPaymentMethodsScreen extends StatefulWidget {
  const ClientPaymentMethodsScreen({super.key});
  static const String route = '/client/payment-methods';

  @override
  State<ClientPaymentMethodsScreen> createState() => _ClientPaymentMethodsScreenState();
}

class _ClientPaymentMethodsScreenState extends State<ClientPaymentMethodsScreen> with WidgetsBindingObserver {
  bool _loading = false;
  String? _error;
  List<ClientPaymentMethod> _items = const [];
  bool _polling = false; // true while we are polling the backend for newly saved cards after redirect/SDK
  bool _awaitingReturn = false; // set to true when we open external Paystack auth URL so we can auto-refresh on resume
  String? _pendingReference; // last link session reference to verify on resume

  String _friendlyError(Object e) {
    // Extract a human-friendly message from DioException or generic errors
    try {
      // Avoid importing Dio here; rely on duck-typing via toString/fields
      final dynamic de = e;
      final resp = de.response;
      if (resp != null) {
        final code = resp.statusCode as int?;
        final data = resp.data;
        String? msg;
        if (data is Map) {
          msg = (data['message'] ?? data['error'] ?? data['detail'])?.toString();
        } else if (data is String) {
          msg = data;
        }
        if (msg != null && msg.trim().isNotEmpty) {
          if (code == 400) return msg; // validation
          return 'Request failed (${code ?? 'error'}): $msg';
        }
      }
    } catch (_) {}
    return e.toString();
  }

  Future<void> _load() async {
    final user = CurrentUserStore.I.user;
    if (user == null || user.id.isEmpty) {
      setState(() {
        _error = 'Not signed in or user not loaded yet';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await PaystackApi.I.listClientPaymentMethods(uid: user.id);
      setState(() {
        _items = items;
      });
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pollForNewMethod({required String uid, required int previousCount, Duration timeout = const Duration(seconds: 180)}) async {
    if (_polling) return; // avoid duplicate polls
    _polling = true;
    final start = DateTime.now();
    // We will attempt to proactively verify the payment session reference while polling.
    // This helps in environments where webhooks are delayed or not configured.
    final ref = _pendingReference ?? PaystackApi.lastCardLinkReference;
    var lastVerifyAt = DateTime.fromMillisecondsSinceEpoch(0);
    const verifyInterval = Duration(seconds: 15); // don't spam the server
    try {
      while (mounted && DateTime.now().difference(start) < timeout) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          // Periodically nudge the backend to persist the card using the session reference
          if (ref != null && ref.isNotEmpty && DateTime.now().difference(lastVerifyAt) >= verifyInterval) {
            lastVerifyAt = DateTime.now();
            // Fire-and-forget: we don't block polling on this network call
            // Any failure here is non-fatal; we'll keep polling the wallet list
            // for the new card to appear.
            // ignore: unawaited_futures
            PaystackApi.I.verifyPaymentSession(reference: ref).catchError((_) {});
          }

          final items = await PaystackApi.I.listClientPaymentMethods(uid: uid);
          if (!mounted) return;
          if (items.length > previousCount) {
            setState(() { _items = items; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Card linked successfully.')),
            );
            return;
          }
        } catch (_) {
          // Ignore transient errors during polling
        }
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _linkCard() async {
    // Prefer in-app SDK tokenization (Uber/Bolt style) using Paystack SDK.
    // Fallback to opening the authorizationUrl in browser if SDK/public key unavailable.
    final user = CurrentUserStore.I.user;
    if (user == null || user.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Load user first')));
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) Ensure a Paystack customer exists (server requirement for some setups).
      try {
        await PaystackApi.I.createClientCustomer(
          uid: user.id,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          phone: user.phoneNumber,
        );
      } catch (_) {
        // Non-fatal: backend may upsert during link-card init; continue.
      }

      // 2) Initialize or verify SDK is ready if public key is available.
      bool sdkReady = false;
      try {
        final pk = await PaystackApi.I.getPaystackPublicKey();
        if (pk != null && pk.isNotEmpty) {
          // Lazy init: only initialize here if not done at app start.
          // Import deferred to keep this screen decoupled from plugin.
          // ignore: unused_import
          // We rely on the service wrapper to avoid tight coupling.
          // PaystackSdkService will throw if plugin init fails.
          //
          // NOTE: This import is at top-level in this file's imports.
          // The service is a thin wrapper around flutter_paystack.
          await PaystackSdkService.I.initOnce(pk);
          sdkReady = true;
        }
      } catch (_) {
        sdkReady = false; // fallback to redirect
      }

      // 3) Ask server to create a zero-amount, tokenize-only link session and return accessCode.
      final init = await PaystackApi.I.initClientCardLink(
        uid: user.id,
        email: user.email.isNotEmpty ? user.email : null,
        amount: 0, // Ensure zero-amount tokenization to avoid ZAR 1 hold/charge
      );
      // Remember the link session reference for fallback verification on resume.
      _pendingReference = init.reference;
      PaystackApi.lastCardLinkReference = init.reference;

      // 4) If SDK is ready and accessCode is present, open in-app card entry.
      if (sdkReady && (init.accessCode != null && init.accessCode!.isNotEmpty)) {
        final ok = await PaystackSdkService.I.checkoutWithAccessCode(
          context: context,
          accessCode: init.accessCode!,
          email: user.email,
        );
        if (ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card added. Pull to refresh to see it.')),
          );
          await _load(); // optimistic refresh; webhook persists the method shortly after
          return;
        }
        // If SDK checkout didn't complete (stub or user canceled), fall back to hosted page.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening secure card screen...')),
          );
        }
        // Do not return; continue to open authorizationUrl fallback below.
      }

      // 5) Fallback: open the authorization URL in an in-app browser view.
      final url = Uri.tryParse(init.authorizationUrl);
      if (url == null) {
        throw StateError('Invalid authorizationUrl');
      }
      _awaitingReturn = true; // Mark that we expect to come back from an external flow
      // We intentionally ignore the boolean result from launchUrl and handle errors via exceptions
      // to avoid any SnackBar accidentally showing a raw boolean like "true"/"false".
      try {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        // If the in-app browser fails, try external browser as a last resort.
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A secure card screen has opened. After completing it, return here. We will auto-refresh shortly.')),
        );
      }
      // Start polling in the background for the new method to appear via webhook.
      // Fire-and-forget: start polling in background and ignore the Future.
      _pollForNewMethod(uid: user.id, previousCount: _items.length);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer initial load slightly to allow CurrentUserStore to populate if needed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // If we launched an external Paystack page, auto-refresh and start polling on return.
      final user = CurrentUserStore.I.user;
      if (_awaitingReturn && user != null && user.id.isNotEmpty) {
        _awaitingReturn = false; // reset the flag
        // First, attempt a server-side verify using the stored reference as a fallback
        final ref = _pendingReference ?? PaystackApi.lastCardLinkReference;
        if (ref != null && ref.isNotEmpty) {
          () async {
            try { await PaystackApi.I.verifyPaymentSession(reference: ref); } catch (_) {}
          }();
        }
        // Then try to reload immediately and start polling to allow webhook persistence/upsert.
        unawaited(_load());
        _pollForNewMethod(uid: user.id, previousCount: _items.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Saved cards',
              style: text.titleLarge?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            if (_polling)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Verifying your card… this can take up to 2–3 minutes. We\'ll update automatically.',
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.error.withOpacity(0.4)),
                ),
                child: Text(_error!, style: text.bodyMedium?.copyWith(color: cs.onErrorContainer)),
              ),

            if (_loading && _items.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),

            if (_items.isNotEmpty)
              Column(
                children: [
                  for (int i = 0; i < _items.length; i++) ...[
                    _PaymentMethodTile(method: _items[i], showDivider: i < _items.length - 1),
                    const SizedBox(height: 16),
                  ]
                ],
              )
            else if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No payment methods yet', style: text.bodyMedium),
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        final user = CurrentUserStore.I.user;
                        final prevCount = _items.length;
                        final res = await Navigator.of(context).pushNamed('/client/payment-methods/add');
                        if (!mounted) return;
                        // Always try to refresh after returning from Add screen
                        await _load();
                        // If Add screen indicated a flow was started/completed, poll for webhook persistence
                        if (res == true && user != null && user.id.isNotEmpty) {
                          // Fire-and-forget polling to surface the new card automatically
                          _pollForNewMethod(uid: user.id, previousCount: prevCount);
                        }
                      },
                icon: const Icon(Icons.credit_card),
                label: const Text('Add card'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({required this.method, this.showDivider = false});
  final ClientPaymentMethod method;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Values displayed on the card face
    final brand = (method.brand?.isNotEmpty == true) ? method.brand! : 'Card';
    final last4 = method.last4 ?? '••••';
    final exp = _formatExp(method.expMonth, method.expYear);

    return Column(
      children: [
        // Realistic credit card widget with the app's green theme
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.58,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _greenGradient(cs),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.onPrimary.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _BrandPill(brand: brand, color: cs.onPrimary),
                              const Spacer(),
                              Icon(Icons.nfc, color: cs.onPrimary.withValues(alpha: 0.9), size: 20),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: cs.onPrimary.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: cs.onPrimary.withValues(alpha: 0.28), width: 1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _maskedNumber(last4),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (exp.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('VALID THRU', style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimary.withValues(alpha: 0.8), letterSpacing: 1.1)),
                                    const SizedBox(height: 2),
                                    Text(exp, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              const Spacer(),
                              if (method.reusable)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cs.onPrimary.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: cs.onPrimary.withValues(alpha: 0.22)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 16, color: cs.onPrimary),
                                      const SizedBox(width: 6),
                                      Text('Reusable', style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider) const SizedBox(height: 0), // spacing handled above
      ],
    );
  }

  // Helpers (kept private to this screen)
  static String _formatExp(String? m, String? y) {
    final mm = m?.trim();
    final yy = y?.trim();
    if (mm == null || mm.isEmpty || yy == null || yy.isEmpty) return '';
    final mm2 = mm.padLeft(2, '0');
    final yy2 = yy.length == 4 ? yy.substring(2) : yy.padLeft(2, '0');
    return '$mm2/$yy2';
  }

  static String _maskedNumber(String last4) {
    final l4 = last4.padLeft(4, '•');
    return '••••  ••••  ••••  $l4';
  }

  static Gradient _greenGradient(ColorScheme cs) {
    final c1 = cs.primary.withValues(alpha: 0.98);
    final c2 = cs.primaryContainer.withValues(alpha: 0.90);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c1, c2],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.brand, required this.color});
  final String brand;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(brand.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
    );
  }
}
