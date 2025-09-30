import 'package:flutter/foundation.dart';
import 'package:client/auth/api_client.dart';
import 'package:client/model/user_model.dart';
import 'package:dio/dio.dart';

const String kUserDetailsPath = '/api/v1/home/user-details'; // Or wherever this is defined

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
      final res = await ApiClient.I.dio.get(kUserDetailsPath);
      if (res.statusCode == 200 && res.data != null) {
        _user = UserModel.fromJson(res.data as Map<String, dynamic>);
      } else {
        _error = 'Failed to load user data: Status ${res.statusCode}';
      }
    } on DioException catch (e) {
      _error = e.response?.statusCode == 401 ? 'Session expired' : 'Failed to load user';
    } catch (_) {
      _error = 'An unexpected error occurred';
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