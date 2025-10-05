import 'package:client/auth/api_client.dart';
import 'package:dio/dio.dart';

class AddressApi {
  /// Sends user's address to /api/v1/profile/address and returns the DTO.
  static Future<Map<String, dynamic>> saveAddress({
    required String userId,
    required String province,
    required String city,
    required String street,
    required String postalCode,
    double? latitude,
    double? longitude,
  }) async {
    final dio = ApiClient.I.dio;
    final payload = <String, dynamic>{
      'userId': userId,
      'province': province.trim(),
      'city': city.trim(),
      'street': street.trim(),
      'postalCode': postalCode.trim(),
      // if (latitude != null && longitude != null) ...{
      //   'latitude': latitude,
      //   'longitude': longitude,
      // },
    };

    try {
      final res = await dio.post(
        '/api/v1/profile/address',
        data: payload,
        options: Options(
          // Content-Type is auto-set to application/json by Dio for Map payloads
          headers: {'Accept': 'application/json'},
        ),
      );
      if (res.statusCode == 200) {
        final data = res.data;
        return (data is Map<String, dynamic>) ? data : <String, dynamic>{};
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'Unexpected status: ${res.statusCode}',
        type: DioExceptionType.badResponse,
      );
    } on DioException catch (e) {
      // Let caller decide how to surface errors; include response body if any.
      final code = e.response?.statusCode;
      final body = e.response?.data;
      throw Exception(
          'Address save failed [${code ?? 'no-status'}]: ${body ?? e.message}');
    }
  }
}