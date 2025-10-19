import 'dart:async';
import 'package:dio/dio.dart';
import 'package:client/auth/api_client.dart';

/// EarningGoalApi
/// ---------------
/// Client wrapper for provider earning goal endpoints.
/// Server contract: see "Features documents/earning-goal-endpoints.md".
///
/// Endpoints (current user/provider):
/// - GET  /api/v1/providers/earning-goal  → returns goal or 204/404 if not set
/// - PUT  /api/v1/providers/earning-goal  → upsert goal
class EarningGoalApi {
  EarningGoalApi(this._dio);
  final Dio _dio;

  static EarningGoalApi get I => EarningGoalApi(ApiClient.I.dio);

  String _n(String path) => normalizeApiPath(ApiClient.I.dio, path);

  // Basic bounded retry for transient network failures
  Future<T> _retry<T>(Future<T> Function() fn, {int maxRetries = 2}) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on TimeoutException {
        if (attempt >= maxRetries) rethrow;
      } on DioException catch (e) {
        final t = e.type;
        final isNet = t == DioExceptionType.connectionTimeout ||
            t == DioExceptionType.sendTimeout ||
            t == DioExceptionType.receiveTimeout ||
            t == DioExceptionType.connectionError;
        if (!isNet || attempt >= maxRetries) rethrow;
      }
      final base = 300 * (1 << attempt);
      final jitter = (90 * (attempt + 1));
      final delayMs = base + (DateTime.now().millisecondsSinceEpoch % jitter);
      await Future.delayed(Duration(milliseconds: delayMs));
      attempt++;
    }
  }

  Future<EarningGoal?> getGoal({Duration timeout = const Duration(seconds: 8), int retries = 2}) async {
    try {
      final res = await _retry(() => _dio
          .get(_n('/api/v1/providers/earning-goal'))
          .timeout(timeout, onTimeout: () => throw TimeoutException('Earning goal request timed out')),
        maxRetries: retries,
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return EarningGoal.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 204) return null; // goal not set yet
      rethrow;
    }
  }

  Future<EarningGoal> setGoal({
    required int amountMinor,
    required String currency,
    required String period, // 'week' | 'month'
    String? startDate, // YYYY-MM-DD
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final payload = <String, dynamic>{
      'amount': amountMinor,
      'currency': currency.toLowerCase(),
      'period': period,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
    };
    final res = await _retry(() => _dio
        .put(_n('/api/v1/providers/earning-goal'), data: payload)
        .timeout(timeout, onTimeout: () => throw TimeoutException('Saving earning goal timed out')),
    );
    final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return EarningGoal.fromJson(data);
  }
}

class EarningGoal {
  final int amount; // minor units
  final String currency; // lowercase ISO
  final String period; // 'week' | 'month'
  final String? startDate; // YYYY-MM-DD

  const EarningGoal({required this.amount, required this.currency, required this.period, this.startDate});

  factory EarningGoal.fromJson(Map<String, dynamic> json) {
    return EarningGoal(
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] ?? 'zar').toString().toLowerCase(),
      period: (json['period'] ?? 'week').toString(),
      startDate: (json['startDate'] as String?)?.trim().isEmpty == true ? null : json['startDate'] as String?,
    );
  }
}
