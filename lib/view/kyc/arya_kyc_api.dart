/// Thin client for YOUR backend which calls Arya.
/// Matches controllers in /api/documents/rsa-id/*
import 'dart:typed_data';
import 'package:dio/dio.dart';

class AryaKycApi {
  AryaKycApi(this._dio);
  final Dio _dio;

  /// Step 1: Verify the front ID image.
  /// Server endpoint: POST /api/documents/rsa-id/front
  /// Form field name: frontIdImage (jpeg/png)
  /// Response shape (example):
  /// {
  ///   "extracted": {
  ///     "idNumber":"...",
  ///     "firstName":"...",
  ///     "lastName":"...",
  ///     "fullName":"...",
  ///     "dateOfBirth":"yyyy-MM-dd or variants",
  ///     "gender":"M|F",
  ///     "ocrConfidence": 0.93,
  ///     "raw": {...}
  ///   },
  ///   "checks": { "idFormatValid": true, "ocrConfidenceOk": true },
  ///   "decision": "AUTO_PASS" | "MANUAL_REVIEW"
  /// }
  Future<Map<String, dynamic>> submitFront({
    required Uint8List frontBytes,
    required String mime, // 'image/jpeg' | 'image/png'
  }) async {
    final form = FormData.fromMap({
      'frontIdImage': MultipartFile.fromBytes(
        frontBytes,
        filename: 'front.jpg',
        contentType: DioMediaType.parse(mime),
      ),
    });
    final res = await _dio.post('/api/documents/rsa-id/front', data: form);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Step 2: Face verify (compare front ID image with selfie-with-ID).
  /// Server endpoint: POST /api/documents/rsa-id/face-verify
  /// Field names: frontIdImage, selfieWithId
  /// Response:
  /// { "similarity": 0.87, "threshold": 0.85, "decision": "AUTO_PASS" | "MANUAL_REVIEW", ... }
  Future<Map<String, dynamic>> faceVerify({
    required Uint8List frontBytes,
    required String frontMime,
    required Uint8List selfieBytes,
    required String selfieMime,
  }) async {
    final form = FormData.fromMap({
      'frontIdImage': MultipartFile.fromBytes(
        frontBytes,
        filename: 'front.jpg',
        contentType: DioMediaType.parse(frontMime),
      ),
      'selfieWithId': MultipartFile.fromBytes(
        selfieBytes,
        filename: 'selfie.jpg',
        contentType: DioMediaType.parse(selfieMime),
      ),
    });
    final res = await _dio.post('/api/documents/rsa-id/face-verify', data: form);
    return Map<String, dynamic>.from(res.data as Map);
  }
}