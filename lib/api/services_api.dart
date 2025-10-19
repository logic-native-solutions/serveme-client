import 'package:client/auth/api_client.dart';
import 'package:dio/dio.dart';

/// Services API + models
///
/// Implements GET /api/v1/services as described in Frontend_integration_guide.md.
/// Keeps models minimal and forward-compatible (ignore unknown fields).
class ServicesApi {
  ServicesApi(this._dio);
  final Dio _dio;

  static ServicesApi get I => ServicesApi(ApiClient.I.dio);

  Future<List<ServiceDoc>> fetchServices() async {
    final res = await _dio.get(_normalize('/api/v1/services'));
    final data = res.data as List<dynamic>;
    return data.map((e) => ServiceDoc.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _normalize(String path) => normalizeApiPath(ApiClient.I.dio, path);
}

class ServiceDoc {
  final String id;
  final String displayName;
  final int basePrice; // cents
  final List<ServiceAddOn> addOns;
  final double? minRadiusKm;
  final double? maxRadiusKm;

  ServiceDoc({
    required this.id,
    required this.displayName,
    required this.basePrice,
    required this.addOns,
    this.minRadiusKm,
    this.maxRadiusKm,
  });

  factory ServiceDoc.fromJson(Map<String, dynamic> json) {
    return ServiceDoc(
      id: json['id'] as String,
      displayName: (json['displayName'] ?? json['name'] ?? '') as String,
      basePrice: (json['basePrice'] ?? 0) as int,
      addOns: ((json['addOns'] as List<dynamic>?) ?? const [])
          .map((a) => ServiceAddOn.fromJson(a as Map<String, dynamic>))
          .toList(),
      minRadiusKm: (json['minRadiusKm'] as num?)?.toDouble(),
      maxRadiusKm: (json['maxRadiusKm'] as num?)?.toDouble(),
    );
  }
}

class ServiceAddOn {
  final String id;
  final String label;
  final int price; // cents

  ServiceAddOn({required this.id, required this.label, required this.price});

  factory ServiceAddOn.fromJson(Map<String, dynamic> json) {
    return ServiceAddOn(
      id: (json['id'] ?? json['code'] ?? '') as String,
      label: (json['label'] ?? json['name'] ?? '') as String,
      price: (json['price'] ?? 0) as int,
    );
  }
}
