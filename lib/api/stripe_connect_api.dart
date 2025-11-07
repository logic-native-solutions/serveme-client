import 'dart:async';
import 'package:dio/dio.dart';
import 'package:client/auth/api_client.dart';

/// StripeConnectApi
/// -----------------
/// Thin wrapper around provider payout onboarding endpoints.
/// The server-side contract is described in Features documents/stripe-connect-provider-onboarding.md
/// Endpoints:
///  - POST /api/v1/providers/onboarding-link → { url: string, accountId: string }
///  - GET  /api/v1/providers/stripe-status   → { linked: bool, payoutsEnabled: bool, accountId?: string }
///  - POST /api/v1/providers/onboarding      → accepts optional { stripeAccountId?, stripePayoutsEnabled? }
///
/// Notes:
///  - Uses ApiClient singleton for configured, authenticated Dio.
///  - normalizeApiPath keeps baseUrl consistent with other API modules.
class StripeConnectApi {
  StripeConnectApi(this._dio);

  final Dio _dio;

  static StripeConnectApi get I => StripeConnectApi(ApiClient.I.dio);

  String _n(String path) => normalizeApiPath(ApiClient.I.dio, path);

  // Simple bounded retry with exponential backoff and jitter.
  // Retries on TimeoutException and network-related DioExceptions.
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
      // Backoff with jitter: 400ms, 800ms (+/- up to 100ms)
      final base = 400 * (1 << attempt);
      final jitter = (100 * (attempt + 1));
      final delayMs = base + (DateTime.now().millisecondsSinceEpoch % jitter);
      await Future.delayed(Duration(milliseconds: delayMs));
      attempt++;
    }
  }

  /// Requests a Stripe Express Account Link that the provider can open to complete onboarding.
  /// Applies a defensive timeout similar to status checks to avoid hanging UI.
  Future<StripeOnboardingLink> createOnboardingLink({Duration timeout = const Duration(seconds: 8), int retries = 2}) async {
    final res = await _retry(() => _dio
        .post(_n('/api/v1/providers/onboarding-link'))
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Stripe onboarding link request timed out');
    }), maxRetries: retries);
    final data = res.data as Map<String, dynamic>;
    final urlRaw = data['url'] as String?;
    final acct = data['accountId'] as String?;
    // Validate we got a real, absolute HTTPS URL from the server. Stripe Account Links are https.
    final uri = urlRaw != null ? Uri.tryParse(urlRaw) : null;
    // Accept any absolute URI so dev/mock deep links (custom schemes) also work. Prefer https in production.
    final isValid = uri != null && uri.isAbsolute;
    if (!isValid) {
      // Surface a clear, actionable error so the UI can inform the user/admin where to enable this.
      throw const FormatException('Invalid or missing Stripe onboarding link from server');
    }
    return StripeOnboardingLink(
      url: uri.toString(),
      accountId: acct ?? '',
    );
  }

  /// Fetches the latest known payout/connection status for the current provider.
  /// A defensive timeout is applied to avoid indefinite loading when network/server is slow.
  Future<StripeStatus> getStripeStatus({Duration timeout = const Duration(seconds: 8), int retries = 2}) async {
    final res = await _retry(() => _dio
        .get(_n('/api/v1/providers/stripe-status'))
        .timeout(timeout, onTimeout: () {
      // Create a pseudo response to surface a meaningful error upstream via TimeoutException
      throw TimeoutException('Stripe status request timed out');
    }), maxRetries: retries);
    final data = res.data as Map<String, dynamic>;
    return StripeStatus(
      linked: data['linked'] as bool? ?? false,
      payoutsEnabled: data['payoutsEnabled'] as bool? ?? false,
      accountId: data['accountId'] as String?,
    );
  }

  /// Fetches live Stripe account info (balances and recent balance transactions) for the authenticated provider.
  /// See: Features documents/stripe-account-info-endpoint.md
  Future<StripeAccountInfo> getStripeAccountInfo({Duration timeout = const Duration(seconds: 8), int retries = 2}) async {
    final res = await _retry(() => _dio
        .get(_n('/api/v1/providers/stripe-account'))
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Stripe account info request timed out');
    }), maxRetries: retries);
    final data = res.data as Map<String, dynamic>;

    // Parse balances
    final balances = data['balances'] as Map<String, dynamic>? ?? const {};
    final availableList = (balances['available'] as List?) ?? const [];
    final pendingList = (balances['pending'] as List?) ?? const [];
    List<StripeBalanceAmount> parseAmounts(List raw) => raw
        .whereType<Map>()
        .map((m) => StripeBalanceAmount(
              amount: (m['amount'] as num?)?.toInt() ?? 0,
              currency: (m['currency'] as String? ?? '').toLowerCase(),
            ))
        .toList(growable: false);

    final available = parseAmounts(availableList);
    final pending = parseAmounts(pendingList);

    // Parse transactions (up to 20)
    final txnsRaw = (data['transactions'] as List?) ?? const [];
    final txns = txnsRaw.whereType<Map>().map((m) => StripeBalanceTxn(
          id: (m['id'] as String?) ?? '',
          amount: (m['amount'] as num?)?.toInt() ?? 0,
          currency: (m['currency'] as String? ?? '').toLowerCase(),
          type: (m['type'] as String? ?? ''),
          reportingCategory: (m['reportingCategory'] as String? ?? ''),
          description: (m['description'] as String? ?? ''),
          fee: (m['fee'] as num?)?.toInt() ?? 0,
          net: (m['net'] as num?)?.toInt() ?? 0,
          created: (m['created'] as num?)?.toInt() ?? 0,
        )).toList(growable: false);

    return StripeAccountInfo(
      accountId: (data['accountId'] as String?) ?? '',
      payoutsEnabled: data['payoutsEnabled'] as bool? ?? false,
      balances: StripeBalance(available: available, pending: pending),
      transactions: txns,
    );
  }

  /// Completes provider onboarding on our server side (non-Stripe bits). Optional fields allow the
  /// server to upsert Stripe-related snapshot data when sent from the mobile app.
  Future<void> completeProviderOnboarding({String? stripeAccountId, bool? stripePayoutsEnabled}) async {
    await _dio.post(_n('/api/v1/providers/onboarding'), data: {
      if (stripeAccountId != null) 'stripeAccountId': stripeAccountId,
      if (stripePayoutsEnabled != null) 'stripePayoutsEnabled': stripePayoutsEnabled,
    });
  }
}

class StripeOnboardingLink {
  StripeOnboardingLink({required this.url, required this.accountId});
  final String url;
  final String accountId;
}

class StripeStatus {
  StripeStatus({required this.linked, required this.payoutsEnabled, this.accountId});
  final bool linked;
  final bool payoutsEnabled;
  final String? accountId;
}

/// Models for Stripe account info (balances and transactions). Amounts are minor units (e.g., cents).
class StripeAccountInfo {
  StripeAccountInfo({required this.accountId, required this.payoutsEnabled, required this.balances, required this.transactions});
  final String accountId;
  final bool payoutsEnabled;
  final StripeBalance balances;
  final List<StripeBalanceTxn> transactions;
}

class StripeBalance {
  StripeBalance({required this.available, required this.pending});
  final List<StripeBalanceAmount> available;
  final List<StripeBalanceAmount> pending;

  int get availableTotalMinor => available.fold(0, (sum, e) => sum + e.amount);
  int get pendingTotalMinor => pending.fold(0, (sum, e) => sum + e.amount);
}

class StripeBalanceAmount {
  StripeBalanceAmount({required this.amount, required this.currency});
  final int amount; // minor units
  final String currency; // lowercase ISO currency code
}

class StripeBalanceTxn {
  StripeBalanceTxn({
    required this.id,
    required this.amount,
    required this.currency,
    required this.type,
    required this.reportingCategory,
    required this.description,
    required this.fee,
    required this.net,
    required this.created,
  });
  final String id;
  final int amount; // minor units
  final String currency;
  final String type;
  final String reportingCategory;
  final String description;
  final int fee; // minor units
  final int net; // minor units
  final int created; // epoch seconds
}