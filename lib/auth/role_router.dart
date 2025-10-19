import 'package:client/auth/api_client.dart';
import 'package:client/auth/role_store.dart';
import 'package:dio/dio.dart';

/// RoleRouter
/// ----------
/// Calls the backend dashboard director endpoint to determine the user's
/// effective role and the appropriate dashboard route to navigate to.
///
/// Backend contract (from Features documents):
///   GET /api/v1/dashboard/redirect
///   200 OK → { "role": "provider|client|user", "target": "/dashboard/provider|/dashboard/client|/dashboard" }
///   401 if not authenticated
///   403 if attempting protected resources without the correct role
class RoleRouter {
  RoleRouter(this._dio);

  final Dio _dio;

  /// Fetches the redirect. Returns a tuple-like map with {role, target} on 200.
  /// Throws DioException on HTTP errors.
  Future<Map<String, String>> fetchRedirect() async {
    final path = normalizeApiPath(_dio, '/api/v1/dashboard/redirect');
    final resp = await _dio.get(path);
    final data = resp.data as Map<String, dynamic>? ?? const {};
    final role = (data['role'] ?? 'user').toString();
    final target = (data['target'] ?? '/dashboard').toString();

    // Cache role in memory for client-side guards
    RoleStore.setRole(role);

    return {'role': role, 'target': target};
  }

  /// Whether the cached role allows provider-only pages.
  bool get isProvider => RoleStore.isProvider;
}
