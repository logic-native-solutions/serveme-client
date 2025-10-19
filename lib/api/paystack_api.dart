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
}
