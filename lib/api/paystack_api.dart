import 'dart:async';
import 'package:dio/dio.dart';
import 'package:client/auth/api_client.dart';
import 'package:client/api/stripe_connect_api.dart' show StripeStatus; // Reuse model to minimize UI changes

/// PaystackApi
/// ------------
/// Thin wrapper around provider Paystack endpoints after migrating from Stripe.
/// We intentionally return StripeStatus in getPaystackStatus to avoid refactoring
/// existing UI components that already consume this shape (linked + payoutsEnabled + accountId).
/// - GET  /api/v1/providers/paystack-status   → { linked: bool, subaccountCode?: string }
/// - POST /api/v1/providers/paystack/subaccount → creates/updates subaccount with bank details
///
/// Notes:
///  - payoutsEnabled is not a Paystack concept in the same way as Stripe; we map it to `linked`.
///  - accountId will carry `subaccountCode` so existing banners can show the code when available.
///  - Upsert resiliency (fallback create when update fails) is handled by the backend.
///    See: Features documents/paystack-upsert-fix.md
class PaystackApi {
  PaystackApi(this._dio);
  final Dio _dio;

  static PaystackApi get I => PaystackApi(ApiClient.I.dio);

  // Holds the last card-link reference initialized by the client.
  // This allows the list screen to verify the session on app resume
  // in environments where webhooks may be delayed or unavailable.
  static String? lastCardLinkReference;

  String _n(String path) => normalizeApiPath(ApiClient.I.dio, path);

  // Simple bounded retry identical to StripeConnectApi's behavior
  Future<T> _retry<T>(Future<T> Function() fn, {int maxRetries = 2}) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on TimeoutException {
        if (attempt >= maxRetries) rethrow;
      } on DioException catch (e) {
        final type = e.type;
        final isNet = type == DioExceptionType.connectionTimeout ||
            type == DioExceptionType.sendTimeout ||
            type == DioExceptionType.receiveTimeout ||
            type == DioExceptionType.connectionError;
        if (!isNet || attempt >= maxRetries) rethrow;
      }
      final base = 400 * (1 << attempt);
      final jitter = (100 * (attempt + 1));
      final delayMs = base + (DateTime.now().millisecondsSinceEpoch % jitter);
      await Future.delayed(Duration(milliseconds: delayMs));
      attempt++;
    }
  }

  /// Fetches Paystack linkage status for the current provider.
  /// Maps the server response to StripeStatus for compatibility with existing widgets.
  /// If the provider has no subaccount yet, the server may return 404 or a body with linked=false.
  /// In both cases, we surface a non-error state with linked=false so the UI can prompt creation.
  Future<StripeStatus> getPaystackStatus({Duration timeout = const Duration(seconds: 8), int retries = 2}) async {
    try {
      final res = await _retry(() => _dio
          .get(_n('/api/v1/providers/paystack-status'))
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('Paystack status request timed out');
      }), maxRetries: retries);
      final data = res.data as Map<String, dynamic>;
      final linked = data['linked'] as bool? ?? false;
      final sub = data['subaccountCode'] as String?; // may be null
      return StripeStatus(
        linked: linked,
        payoutsEnabled: linked, // Treat linked as payouts ready for UI toggles
        accountId: sub, // surface the subaccount code in status banners
      );
    } on DioException catch (e) {
      // If the API signals "not found" (no subaccount yet), don't treat as failure.
      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 204) {
        return StripeStatus(linked: false, payoutsEnabled: false, accountId: null);
      }
      rethrow;
    }
  }

  /// Fetches Paystack account snapshot: subaccount, balances summary, recent transactions and settlements.
  /// See Features documents/paystack-account-fetch.md
  Future<PaystackAccountSnapshot> getAccountSnapshot({Duration timeout = const Duration(seconds: 10), int retries = 2}) async {
    try {
      final res = await _retry(() => _dio
          .get(_n('/api/v1/providers/paystack/account'))
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('Paystack account fetch timed out');
      }), maxRetries: retries);
      final data = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
      return PaystackAccountSnapshot.fromJson(data);
    } on DioException catch (e) {
      // If not linked, backend should return 404 with reason not_linked per spec.
      rethrow;
    }
  }

  /// Lists South African banks from the backend helper endpoint to populate a bank name picker.
  /// Returns a list of display names. The backend proxies Paystack /bank and may include code/slug internally.
  Future<List<String>> getSABanks({Duration timeout = const Duration(seconds: 8), int retries = 2}) async {
    final res = await _retry(() => _dio
        .get(_n('/api/v1/providers/paystack/banks'))
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Paystack banks request timed out');
    }), maxRetries: retries);
    final body = res.data;
    if (body is List) {
      // Backend may return list of {name, code, slug} maps or strings; normalize to names.
      final names = <String>[];
      for (final item in body) {
        if (item is String) {
          names.add(item);
        } else if (item is Map) {
          final n = (item['name'] ?? item['bankName'] ?? item['display'] ?? '').toString();
          if (n.isNotEmpty) names.add(n);
        }
      }
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return names;
    }
    if (body is Map && body['banks'] is List) {
      final list = (body['banks'] as List);
      return list
          .map((e) => e is Map ? (e['name'] ?? e['bankName'] ?? '').toString() : e.toString())
          .where((e) => e.trim().isNotEmpty)
          .map((e) => e.trim())
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return const <String>[];
  }

  /// Fetches the configured platform commission percent if the backend exposes it on status.
  /// Returns null if not provided by the server. This uses the same status endpoint to avoid new contracts.
  Future<double?> getCommissionPercent({Duration timeout = const Duration(seconds: 8), int retries = 2}) async {
    try {
      final res = await _retry(() => _dio
              .get(_n('/api/v1/providers/paystack-status'))
              .timeout(timeout, onTimeout: () {
            throw TimeoutException('Paystack status request timed out');
          }),
          maxRetries: retries);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final v = data['commissionPercent'] ?? data['percentageCharge'] ?? data['platformFeePercent'];
        if (v is num) return v.toDouble();
        if (v is String) {
          final d = double.tryParse(v);
          if (d != null) return d;
        }
      }
      return null;
    } on TimeoutException {
      // Commission is purely informational (read-only). If the server is slow, do not block onboarding.
      return null;
    } on DioException catch (e) {
      // If no subaccount configured yet and server returns 404, we still may want to show the configured commission.
      // Many servers will still include commission on 200 with linked=false; otherwise, silently ignore.
      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 204) return null;
      rethrow;
    }
  }

  /// Creates or updates a Paystack subaccount for the provider.
  /// Updated for SA bank auto-resolve (see Features documents/paystack-sa-bank-auto-resolve.md):
  ///  - Prefer sending `bankName` (human readable, e.g., "FNB", "Standard Bank").
  ///  - `settlementBank` remains supported for backward compatibility but is optional.
  ///  - Server resolves the correct bank code/slug when only `bankName` is provided.
  Future<Map<String, dynamic>> upsertSubaccount({
    required String businessName,
    String? bankName,
    String? settlementBank,
    required String accountNumber,
    String? settlementSchedule,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // Normalize inputs to reduce backend validation failures.
    // - accountNumber: remove spaces/hyphens commonly entered by users.
    // - settlementSchedule: default to 'auto' if not provided (server accepts and may override).
    final normalizedAccount = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final effectiveSchedule = (settlementSchedule == null || settlementSchedule.trim().isEmpty)
        ? 'auto'
        : settlementSchedule.trim();

    final payload = <String, dynamic>{
      'businessName': businessName.trim(),
      'accountNumber': normalizedAccount,
      if (bankName != null && bankName.isNotEmpty) 'bankName': bankName.trim(),
      if (settlementBank != null && settlementBank.isNotEmpty) 'settlementBank': settlementBank.trim(),
      // Optional in backend; send a sane default to avoid 400s from strict validators.
      'settlementSchedule': effectiveSchedule,
    };
    // Slightly longer timeout to accommodate Paystack network latency during subaccount creation.
    final res = await _retry(() => _dio
        .post(_n('/api/v1/providers/paystack/subaccount'), data: payload)
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Paystack subaccount request timed out');
    }));
    final data = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return data;
  }
    /// ==========================
  /// Client (Payer) Endpoints
  /// ==========================
  /// These adapt to the server changes for client Paystack onboarding & card linking.
  /// See Features documents/client-paystack-onboarding.md

  /// Creates or updates a Paystack Customer for a client uid and persists the customer_code server-side.
  /// Returns a minimal payload with provider and customer_code.
  Future<Map<String, dynamic>> createClientCustomer({
    required String uid,
    required String email,
    String? firstName,
    String? lastName,
    String? phone,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phone != null) 'phone': phone,
    };
    final res = await _retry(() => _dio
        .post(_n('/api/v1/clients/$uid/paystack/customer'), data: payload)
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Paystack customer request timed out');
    }));
    final data = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return data;
  }

  /// Initializes a card link (tokenization) transaction for the client.
  /// Server responds with authorizationUrl, accessCode, and reference.
  Future<ClientCardLinkInit> initClientCardLink({
    required String uid,
    String? email,
    int amount = 0, // Prefer zero-amount auth for pure card tokenization
    String currency = 'ZAR',
    String? callbackUrl,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // Backward/forward compatible init flow with graceful fallbacks to avoid 400s
    // across backend versions. We try the new endpoint first, then simplify the
    // payload, then fall back to the legacy path.
    final cb = (callbackUrl != null && callbackUrl.isNotEmpty)
        ? callbackUrl
        : 'serveme://paystack-return'; // Default deep link for return

    Future<ClientCardLinkInit> _attempt(String path, Map<String, dynamic> data) async {
      final res = await _retry(() => _dio
          .post(_n(path), data: data)
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('Paystack link-card init timed out');
      }));
      final map = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
      return ClientCardLinkInit.fromJson(map);
    }

    // 1) Try modern endpoint with full hints for tokenize-only flow
    final fullPayload = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      'amount': amount,
      'currency': currency,
      'tokenizeOnly': true,
      'mode': 'card_link',
      'callbackUrl': cb,
    };
    try {
      return await _attempt('/api/v1/clients/$uid/paystack/link-card/init', fullPayload);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (!(code == 400 || code == 404 || code == 422)) rethrow;
      // Continue to next strategy
    }

    // 2) Same endpoint, minimal payload (compat with stricter validators)
    final minimalPayload = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      'callbackUrl': cb,
    };
    try {
      return await _attempt('/api/v1/clients/$uid/paystack/link-card/init', minimalPayload);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (!(code == 400 || code == 404 || code == 422)) rethrow;
      // Continue to next strategy
    }

    // 3) Legacy path used in earlier iterations
    try {
      return await _attempt('/api/v1/payments/card-link/init', minimalPayload);
    } on DioException {
      // Propagate last error to caller for user feedback
      rethrow;
    }
  }

  /// Lists saved payment methods for the given client uid.
  /// Uses new path /api/v1/payments/wallet/payment-methods?uid=... with fallback
  /// to legacy /api/v1/clients/{uid}/paystack/payment-methods for backwards compatibility.
  Future<List<ClientPaymentMethod>> listClientPaymentMethods({
    required String uid,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Response res;
    try {
      // New unified wallet endpoint (preferred)
      res = await _retry(() => _dio
          .get(_n('/api/v1/payments/wallet/payment-methods'), queryParameters: {'uid': uid})
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('Wallet payment methods request timed out');
      }));
    } on DioException catch (_) {
      // Fallback to legacy client-scoped endpoint
      res = await _retry(() => _dio
          .get(_n('/api/v1/clients/$uid/paystack/payment-methods'))
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('Paystack payment methods request timed out');
      }));
    }
    final body = res.data;
    final items = <ClientPaymentMethod>[];
    if (body is Map && body['items'] is List) {
      for (final e in (body['items'] as List)) {
        if (e is Map<String, dynamic>) {
          items.add(ClientPaymentMethod.fromJson(e));
        } else if (e is Map) {
          items.add(ClientPaymentMethod.fromJson(e.cast<String, dynamic>()));
        }
      }
    } else if (body is List) {
      for (final e in body) {
        if (e is Map<String, dynamic>) items.add(ClientPaymentMethod.fromJson(e));
      }
    }
    return items;
  }

  /// Estimates upfront price (base, distance, fees, subtotal, total) for a service
  /// using the new server endpoint: POST /api/v1/payments/estimate
  /// Request accepts either serviceId or basePrice and optional addOnIds/distanceKm/perKmCents.
  Future<Map<String, dynamic>> estimatePayment({
    String? serviceId,
    int? basePrice,
    String currency = 'ZAR',
    double? distanceKm,
    int? perKmCents,
    List<String>? addOnIds,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final payload = <String, dynamic>{
      if (serviceId != null && serviceId.isNotEmpty) 'serviceId': serviceId,
      if (basePrice != null) 'basePrice': basePrice,
      if (currency.isNotEmpty) 'currency': currency,
      if (distanceKm != null) 'distanceKm': distanceKm,
      if (perKmCents != null) 'perKmCents': perKmCents,
      if (addOnIds != null && addOnIds.isNotEmpty) 'addOnIds': addOnIds,
    };
    final res = await _retry(() => _dio
        .post(_n('/api/v1/payments/estimate'), data: payload)
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Estimate request timed out');
    }));
    final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return data;
  }

  /// Fetch Paystack public key for SDK initialization (client-side tokenization)
  /// Server: GET /api/v1/paystack/public-key -> { publicKey: "pk_xxx" }
  /// Returns null if not configured or endpoint unavailable (404/503).
  Future<String?> getPaystackPublicKey({Duration timeout = const Duration(seconds: 6), int retries = 1}) async {
    try {
      final res = await _retry(() => _dio
              .get(_n('/api/v1/paystack/public-key'))
              .timeout(timeout, onTimeout: () {
            throw TimeoutException('Paystack public key request timed out');
          }),
          maxRetries: retries);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final key = data['publicKey'] ?? data['public_key'];
        if (key is String && key.isNotEmpty) return key;
      }
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 503) return null; // treat as not configured
      rethrow;
    } on TimeoutException {
      return null; // non-critical
    }
  }

  /// Attach the user's selected payment method to a job so the backend can charge later
  /// per the Paystack architecture (link card now, charge on completion). This mirrors
  /// the backend route: POST /api/v1/jobs/{jobId}/prepare-payment with body { paymentMethodId }.
  /// Note: In the current client, paymentMethodId is the saved Paystack authorization_code.
  Future<Map<String, dynamic>> prepareJobPayment({
    required String jobId,
    required String paymentMethodId,
    String? uid, // New server requires uid in body; kept optional for backward compatibility
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final payload = <String, dynamic>{
      'paymentMethodId': paymentMethodId,
      if (uid != null && uid.isNotEmpty) 'uid': uid,
    };
    final res = await _retry(() => _dio
        .post(_n('/api/v1/jobs/$jobId/prepare-payment'), data: payload)
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Prepare payment request timed out');
    }));
    final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return data;
  }

  /// Places a Paystack authorization hold for the specified job using the
  /// previously selected payment method (attached during prepare-payment).
  /// Mirrors new server endpoint: POST /api/v1/jobs/{jobId}/charge with body { uid }.
  Future<Map<String, dynamic>> chargeJobHold({
    required String jobId,
    required String uid,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final res = await _retry(() => _dio
        .post(_n('/api/v1/jobs/$jobId/charge'), data: {'uid': uid})
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Charge hold request timed out');
    }));
    final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return data;
  }

  /// Verifies a Paystack payment session by reference and, when purpose=card_link,
  /// instructs the backend to persist the reusable authorization. Use this after
  /// the user returns from the hosted Paystack page in environments without webhooks.
  /// Mirrors: GET /api/v1/payments/session/{reference}
  Future<Map<String, dynamic>> verifyPaymentSession({
    required String reference,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final res = await _retry(() => _dio
        .get(_n('/api/v1/payments/session/$reference'))
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Verify session request timed out');
    }));
    final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return data;
  }

  Future<Map<String, dynamic>> chargeClientPayment({
    required String uid,
    required String jobId,
    required int amount,
    String currency = 'ZAR',
    required String email,
    required String authorizationCode,
    String? providerSubaccount,
    Map<String, dynamic>? metadata,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final payload = <String, dynamic>{
      'jobId': jobId,
      'amount': amount,
      'currency': currency,
      'email': email,
      'authorizationCode': authorizationCode,
      if (providerSubaccount != null && providerSubaccount.isNotEmpty) 'providerSubaccount': providerSubaccount,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };
    final res = await _retry(() => _dio
        .post(_n('/api/v1/clients/$uid/pay/charge'), data: payload)
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Charge request timed out');
    }));
    final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return data;
  }
}

/// Data transfer objects for the Paystack account snapshot contract.
/// We keep them lightweight (maps/primitive fields) so UI can evolve without
/// frequent client updates.
class PaystackAccountSnapshot {
  PaystackAccountSnapshot({
    required this.subaccountCode,
    required this.subaccount,
    required this.balances,
    required this.transactions,
    required this.settlements,
  });
  final String? subaccountCode; // may be null if backend chooses
  final Map<String, dynamic> subaccount; // raw /subaccount payload
  final PaystackBalances balances;
  final List<PaystackTransaction> transactions;
  final List<PaystackSettlement> settlements;

  factory PaystackAccountSnapshot.fromJson(Map<String, dynamic> json) {
    final sub = (json['subaccount'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final balances = PaystackBalances.fromJson((json['balances'] as Map?)?.cast<String, dynamic>() ?? const {});
    final txRaw = (json['transactions'] as List?) ?? const [];
    final stRaw = (json['settlements'] as List?) ?? const [];
    return PaystackAccountSnapshot(
      subaccountCode: json['subaccountCode']?.toString(),
      subaccount: sub,
      balances: balances,
      transactions: txRaw.whereType<Map>().map((m) => PaystackTransaction.fromJson(m.cast<String, dynamic>())).toList(),
      settlements: stRaw.whereType<Map>().map((m) => PaystackSettlement.fromJson(m.cast<String, dynamic>())).toList(),
    );
  }

  String? get businessName {
    // Common Paystack fields: business_name; fallbacks: businessName, name
    final n = (subaccount['business_name'] ?? subaccount['businessName'] ?? subaccount['name'])?.toString();
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return null;
  }
}

class PaystackBalances {
  PaystackBalances({required this.available, required this.pending, required this.currency, this.note});
  final int available; // minor units in Paystack? For UI, server returns integers; may be 0
  final int pending;
  final String currency; // e.g., ZAR
  final String? note; // informational string for UI tooltip/help

  factory PaystackBalances.fromJson(Map<String, dynamic> json) => PaystackBalances(
        available: (json['available'] as num?)?.toInt() ?? 0,
        pending: (json['pending'] as num?)?.toInt() ?? 0,
        currency: (json['currency'] as String? ?? 'ZAR').toUpperCase(),
        note: json['note']?.toString(),
      );
}

class PaystackTransaction {
  PaystackTransaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.description,
    required this.status,
    required this.paidAt,
    this.createdAt,
    this.reference,
    this.channel,
    this.authorization,
  });
  final String id;
  final int amount; // assume minor units
  final String currency; // lowercase or uppercase ISO
  final String description;
  final String status;
  final String? paidAt; // ISO date strings from Paystack
  final String? createdAt;
  final String? reference;
  final String? channel;
  final PaystackAuthorizationSummary? authorization;

  factory PaystackTransaction.fromJson(Map<String, dynamic> json) => PaystackTransaction(
        id: (json['id'] ?? json['reference'] ?? json['trx'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        currency: (json['currency'] as String? ?? 'ZAR'),
        description: (json['description'] ?? json['message'] ?? json['gateway_response'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        paidAt: json['paid_at']?.toString() ?? json['paidAt']?.toString(),
        createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
        reference: json['reference']?.toString(),
        channel: json['channel']?.toString(),
        authorization: (json['authorization'] is Map)
            ? PaystackAuthorizationSummary.fromJson((json['authorization'] as Map).cast<String, dynamic>())
            : null,
      );
}

class PaystackAuthorizationSummary {
  PaystackAuthorizationSummary({
    required this.authorizationCode,
    this.brand,
    this.last4,
  });
  final String authorizationCode;
  final String? brand;
  final String? last4;

  factory PaystackAuthorizationSummary.fromJson(Map<String, dynamic> json) => PaystackAuthorizationSummary(
        authorizationCode: (json['authorization_code'] ?? json['code'] ?? '').toString(),
        brand: json['brand']?.toString(),
        last4: json['last4']?.toString(),
      );
}

class PaystackSettlement {
  PaystackSettlement({
    required this.id,
    required this.amount,
    required this.settlementDate,
    required this.status,
  });
  final String id;
  final int amount;
  final String? settlementDate; // ISO date or null
  final String status;

  factory PaystackSettlement.fromJson(Map<String, dynamic> json) => PaystackSettlement(
        id: (json['id'] ?? json['batch_code'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        settlementDate: json['settlement_date']?.toString(),
        status: (json['status'] ?? '').toString(),
      );
}

/// Lists Paystack transactions for a client for history screens.
/// Mirrors: GET /api/v1/clients/{uid}/paystack/transactions with optional filters.
Future<List<PaystackTransaction>> listClientTransactions({
  required String uid,
  String? authorizationCode,
  String? status,
  int perPage = 20,
  int page = 1,
  Duration timeout = const Duration(seconds: 10),
}) async {
  // Note: This is a top-level helper (not a PaystackApi instance method) to
  // avoid breaking existing imports. It cannot use PaystackApi._dio/_n/_retry,
  // so we reference ApiClient directly and normalize the path inline.
  final dio = ApiClient.I.dio;
  final qp = <String, dynamic>{
    if (authorizationCode != null && authorizationCode.isNotEmpty) 'authorizationCode': authorizationCode,
    if (status != null && status.isNotEmpty) 'status': status,
    'perPage': perPage,
    'page': page,
  };
  final path = normalizeApiPath(dio, '/api/v1/clients/$uid/paystack/transactions');
  final res = await dio
      .get(path, queryParameters: qp)
      .timeout(timeout, onTimeout: () {
    throw TimeoutException('Transactions request timed out');
  });
  final body = res.data;
  final items = <PaystackTransaction>[];
  final list = (body is Map && body['items'] is List)
      ? body['items'] as List
      : (body is List) ? body : const [];
  for (final e in list) {
    if (e is Map<String, dynamic>) {
      items.add(PaystackTransaction.fromJson(e));
    } else if (e is Map) {
      items.add(PaystackTransaction.fromJson(e.cast<String, dynamic>()));
    }
  }
  return items;
}

/// Client card link init response DTO
class ClientCardLinkInit {
  ClientCardLinkInit({required this.provider, required this.authorizationUrl, required this.accessCode, required this.reference});
  final String? provider; // 'paystack'
  final String authorizationUrl;
  final String? accessCode;
  final String reference; // Paystack transaction reference for the link session

  factory ClientCardLinkInit.fromJson(Map<String, dynamic> json) => ClientCardLinkInit(
        provider: json['provider']?.toString(),
        // Accept multiple aliases for the redirect URL to adapt to backend changes
        authorizationUrl: (json['authorizationUrl'] ?? json['authorization_url'] ?? json['url'] ?? '').toString(),
        accessCode: json['accessCode']?.toString() ?? json['access_code']?.toString(),
        reference: (json['reference'] ?? '').toString(),
      );
}

/// Client saved payment method DTO (reusable authorization)
class ClientPaymentMethod {
  ClientPaymentMethod({
    required this.authorizationCode,
    required this.reusable,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.bank,
    this.countryCode,
    this.channel,
    this.email,
    this.createdAt,
  });

  final String authorizationCode;
  final bool reusable;
  final String? brand;
  final String? last4;
  final String? expMonth;
  final String? expYear;
  final String? bank;
  final String? countryCode;
  final String? channel;
  final String? email;
  final String? createdAt; // ISO string saved by server

  factory ClientPaymentMethod.fromJson(Map<String, dynamic> json) => ClientPaymentMethod(
        authorizationCode: (json['authorization_code'] ?? json['id'] ?? json['code'] ?? '').toString(),
        reusable: (json['reusable'] as bool?) ?? (json['reusable']?.toString() == 'true'),
        brand: json['brand']?.toString(),
        last4: json['last4']?.toString(),
        expMonth: (json['exp_month'] ?? json['expMonth'])?.toString(),
        expYear: (json['exp_year'] ?? json['expYear'])?.toString(),
        bank: json['bank']?.toString(),
        countryCode: (json['country_code'] ?? json['countryCode'])?.toString(),
        channel: json['channel']?.toString(),
        email: json['email']?.toString(),
        createdAt: (json['createdAt'] ?? json['created_at'])?.toString(),
      );
}
