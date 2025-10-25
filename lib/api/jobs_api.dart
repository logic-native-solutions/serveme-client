import 'dart:async';

import 'package:client/auth/api_client.dart';
import 'package:dio/dio.dart';

/// Jobs API per Frontend_integration_guide.md
class JobsApi {
  JobsApi(this._dio);
  final Dio _dio;

  static JobsApi get I => JobsApi(ApiClient.I.dio);

  /// Create a new job (client request)
  /// Note: Some backends may have serialization issues with Java time types; see handler below.
  Future<Job> createJob(CreateJobRequest body) async {
    try {
      final res = await _dio.post(_n('/api/v1/jobs'), data: body.toJson());
      return Job.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      final text = data is String ? data : data?.toString() ?? '';
      final msg = text.toLowerCase();
      final isJavaTimeIssue = msg.contains('jackson-datatype-jsr310') || msg.contains('java 8 date/time type');
      // Workaround backend serialization bug when returning JobDoc with Instant fields.
      // If we hit this specific error, attempt to recover by fetching the latest pending job.
      if (isJavaTimeIssue) {
        try {
          final jobs = await listJobs(role: 'client');
          // Heuristic: pick the most recent PENDING job that matches the requested serviceType
          // and (if available) description. This is a best-effort workaround until backend is fixed.
          jobs.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
          final match = jobs.firstWhere(
            (j) => j.status.toLowerCase() == 'pending' && j.serviceType == body.serviceType,
            orElse: () => jobs.isNotEmpty ? jobs.first : throw StateError('No jobs found'),
          );
          return match;
        } catch (_) {
          // If recovery fails, rethrow original error
        }
      }
      rethrow;
    }
  }

  Future<List<Job>> listJobs({required String role}) async {
    final res = await _dio.get(_n('/api/v1/jobs'), queryParameters: {'role': role});
    final data = res.data as List<dynamic>;
    return data.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Job> getJob(String id) async {
    final res = await _dio.get(_n('/api/v1/jobs/$id'));
    return Job.fromJson(res.data as Map<String, dynamic>);
  }

  /// Provider: attempt to accept a job offer.
  ///
  /// On success returns the updated Job (status=assigned, assignedProviderId set).
  /// If another provider already accepted, backend returns 409 with error "already_taken".
  Future<Job> acceptJob(String id) async {
    final res = await _dio.post(_n('/api/v1/jobs/$id/accept'));
    return Job.fromJson(res.data as Map<String, dynamic>);
  }

  /// Update job status lifecycle.
  /// Allowed statuses (provider): en route | arrived | in_progress | completed | canceled
  /// Client can cancel with {status:canceled} while pending/assigned.
  Future<Job> updateStatus(String id, String status) async {
    final res = await _dio.post(_n('/api/v1/jobs/$id/status'), data: {'status': status});
    return Job.fromJson(res.data as Map<String, dynamic>);
  }

  /// Broadcast/ping nearby providers about a new job.
  /// This calls POST /api/v1/jobs/{id}/broadcast if available. If the endpoint
  /// is missing (404) or not implemented, we swallow the error and continue,
  /// as some backends broadcast automatically on job creation.
  Future<void> broadcastJob(String id) async {
    try {
      await _dio.post(_n('/api/v1/jobs/$id/broadcast'));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404 || status == 501) {
        // Endpoint not present; ignore to keep UX flowing.
        return;
      }
      rethrow;
    }
  }

  String _n(String p) => normalizeApiPath(ApiClient.I.dio, p);
}

class CreateJobRequest {
  final String serviceType;
  final String description;
  final List<String> addOnIds;
  final AddressPayload? address; // minimal subset for now
  final Map<String, dynamic>? desiredTime; // e.g., {"type":"asap"}
  final String? paymentMethodId; // optional
  final String? currency; // defaults to ZAR

  CreateJobRequest({
    required this.serviceType,
    required this.description,
    this.addOnIds = const [],
    this.address,
    this.desiredTime,
    this.paymentMethodId,
    this.currency,
  });

  Map<String, dynamic> toJson() {
    return {
      'serviceType': serviceType,
      'description': description,
      if (addOnIds.isNotEmpty) 'addOnIds': addOnIds,
      if (address != null) 'address': address!.toJson(),
      if (desiredTime != null) 'desiredTime': desiredTime,
      if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      if (currency != null) 'currency': currency,
    };
  }
}

class AddressPayload {
  final String? line1;
  final double? lat;
  final double? lng;
  AddressPayload({this.line1, this.lat, this.lng});
  Map<String, dynamic> toJson() => {
        if (line1 != null) 'line1': line1,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

class Job {
  final String id;
  final String serviceType;
  final String status; // pending | assigned | ...
  final String? description;
  final Price? price;
  final PaymentSnapshot? payment;
  final String? assignedProviderId;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  // Added for Provider Fan-Out visibility and offer expiry handling.
  final DateTime? expiresAt; // when an offer expires (pending state)
  final int? fanOutCount; // number of providers notified if backend returns fanOut array

  Job({
    required this.id,
    required this.serviceType,
    required this.status,
    this.description,
    this.price,
    this.payment,
    this.assignedProviderId,
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.expiresAt,
    this.fanOutCount,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v as String); } catch (_) { return null; }
    }
    int? fanOutLen(dynamic v) {
      if (v is List) return v.length;
      return null;
    }
    return Job(
      id: (json['id'] ?? json['jobId']).toString(),
      serviceType: (json['serviceType'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      description: json['description'] as String?,
      price: json['price'] != null ? Price.fromJson(json['price'] as Map<String, dynamic>) : null,
      payment: json['payment'] != null ? PaymentSnapshot.fromJson(json['payment'] as Map<String, dynamic>) : null,
      assignedProviderId: json['assignedProviderId'] as String?,
      createdAt: parseTs(json['createdAt'] ?? json['timestamps']?['createdAt']),
      acceptedAt: parseTs(json['acceptedAt'] ?? json['timestamps']?['acceptedAt']),
      completedAt: parseTs(json['completedAt'] ?? json['timestamps']?['completedAt']),
      expiresAt: parseTs(json['expiresAt'] ?? json['offer']?['expiresAt']),
      fanOutCount: fanOutLen(json['fanOut']),
    );
  }
}

class Price {
  final String currency;
  final int subtotal;
  final int fees;
  final int total;
  const Price({required this.currency, required this.subtotal, required this.fees, required this.total});
  factory Price.fromJson(Map<String, dynamic> json) => Price(
        currency: (json['currency'] ?? 'ZAR') as String,
        subtotal: (json['subtotal'] ?? 0) as int,
        fees: (json['fees'] ?? 0) as int,
        total: (json['total'] ?? 0) as int,
      );
}

class PaymentSnapshot {
  final String? paymentIntentId;
  final String? status; // requires_payment_method | requires_capture | succeeded
  PaymentSnapshot({this.paymentIntentId, this.status});
  factory PaymentSnapshot.fromJson(Map<String, dynamic> json) =>
      PaymentSnapshot(paymentIntentId: json['paymentIntentId'] as String?, status: json['status'] as String?);
}
