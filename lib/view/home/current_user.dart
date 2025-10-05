import 'package:flutter/foundation.dart';
import 'package:client/auth/api_client.dart';
import 'package:client/model/user_model.dart';
import 'package:dio/dio.dart';


const String kUserDetailsPath = '/api/v1/home/user-details'; // Or wherever this is defined

/// Ensure we don't call `/api/api/...` when baseUrl already includes `/api`.
String _normalizedUserPath(Dio dio, String path) {
  final base = dio.options.baseUrl;
  final hasApiInBase = base.endsWith('/api') || base.contains('/api/');
  if (hasApiInBase && path.startsWith('/api/')) {
    return path.replaceFirst('/api/', '/');
  }
  return path;
}

class CurrentUserStore extends ChangeNotifier {
  CurrentUserStore._();
  static final I = CurrentUserStore._();

  UserModel? _user;
  UserModel? get user => _user;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<UserModel?> load({bool force = false}) async {
    if (_user != null && !force) return _user;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reqPath = _normalizedUserPath(ApiClient.I.dio, kUserDetailsPath);
      final res = await ApiClient.I.dio.get(reqPath);
      if (res.statusCode == 200 && res.data != null) {
        _user = UserModel.fromJson(res.data as Map<String, dynamic>);
      } else {
        _error = 'Failed to load user data: Status ${res.statusCode}';
        debugPrint('[CurrentUserStore] GET $reqPath failed with status ${res.statusCode}; data=${res.data}');
      }
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 401) {
        _error = 'Session expired';
      } else {
        _error = 'Failed to load user: ${e.message ?? e.toString()}';
      }
      debugPrint('[CurrentUserStore] DioException on GET $kUserDetailsPath -> ${e.response?.statusCode} ${e.message}');
      if (e.response != null) {
        debugPrint('[CurrentUserStore] Response data: ${e.response?.data}');
      }
      debugPrint('[CurrentUserStore] Stack: $st');
    } catch (e, st) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('[CurrentUserStore] Unexpected error on GET $kUserDetailsPath: $e');
      debugPrint('[CurrentUserStore] Stack: $st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _user;
  }

  void clear() {
    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}