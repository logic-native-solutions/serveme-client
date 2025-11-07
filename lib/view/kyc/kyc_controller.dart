/// KYC Controller — uses Arya via your backend, camera-only capture.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:client/auth/api_client.dart'; // your shared Dio instance
import 'package:dio/dio.dart';
import 'arya_kyc_api.dart';
import 'kyc_models.dart';

class KycController extends ChangeNotifier {
  KycController() : api = AryaKycApi(ApiClient.I.dio);

  final AryaKycApi api;

  // ----------------------- Observable state -----------------------
  KycStep step = KycStep.document;
  bool isValidating = false;
  bool isUploading = false;

  PickedImage? documentImage;         // live ID capture
  PickedImage? selfieImage;           // live selfie-with-ID

  OcrResult? ocr;
  MismatchInfo? mismatch;
  FaceMatchResult? face;

  String? docDecision;     // 'AUTO_PASS' | 'MANUAL_REVIEW' from /front
  String? faceDecision;    // 'AUTO_PASS' | 'MANUAL_REVIEW' from /face-verify
  double? faceThreshold;   // threshold returned by /face-verify

  bool get isComplete => step == KycStep.done;

  // ----------------------- Document ------------------------------
  Future<void> setDocumentImage(PickedImage img) async {
    // Basic local guard: ensure minimum size (~720px smallest side).
    if (img.bytes.lengthInBytes < 60 * 1024) {
      throw StateError('Image too small/low quality');
    }
    documentImage = img;
    ocr = null;
    mismatch = null;
    notifyListeners();
  }

  // Note: backend now computes field comparisons; expected* params kept for compatibility only.
  Future<void> submitDocumentForOcr({
    required String expectedName,
    required DateTime expectedDob,
    String? expectedIdNumber,
    String? expectedGender, // 'M' or 'F'
  }) async {
    if (documentImage == null) return;

    isUploading = true;
    isValidating = true;
    notifyListeners();

    try {
      // Call backend: /api/documents/rsa-id/front
      final res = await api.submitFront(
        frontBytes: documentImage!.bytes,
        mime: documentImage!.mime,
      );

      // Map payload
      final extracted = (res['extracted'] as Map?) ?? const {};
      final checks = (res['checks'] as Map?) ?? const {};

      final String? idNum = (extracted['idNumber'] ?? extracted['identity_number']) as String?;
      final String? firstName = extracted['firstName'] as String?;
      final String? lastName  = extracted['lastName']  as String?;
      final String? fullName  = extracted['fullName']  as String?;
      final String? dobStr    = extracted['dateOfBirth'] as String?;
      final String? gender    = (extracted['gender'] ?? extracted['sex']) as String?;
      final double? conf      = (extracted['ocrConfidence'] is num) ? (extracted['ocrConfidence'] as num).toDouble() : null;

      DateTime? parsedDob;
      if (dobStr != null) {
        parsedDob = DateTime.tryParse(dobStr) ?? _tryParseDobFallbacks(dobStr);
      }
      docDecision = (res['decision']?.toString());

      ocr = OcrResult(
        name: fullName ?? [if (firstName != null) firstName, if (lastName != null) lastName].whereType<String>().join(' ').trim(),
        dob: parsedDob,
        idNumber: idNum,
        // Map quality flags: idFormatValid → cornersOk (best proxy), ocrConfidenceOk → glareOk (best proxy)
        cornersOk: (checks['idFormatValid'] ?? true) == true,
        blurOk: true, // server doesn't return blur flag; treat as true unless you add it
        glareOk: (checks['ocrConfidenceOk'] ?? true) == true,
      );

      // Use mismatches returned by the server (authoritative)
      final serverMismatches = (res['mismatches'] is List)
          ? (res['mismatches'] as List).whereType<String>().toList()
          : <String>[];
      mismatch = serverMismatches.isEmpty ? null : MismatchInfo(serverMismatches);
    } on DioException catch (e) {
      // Make backend errors readable for UI (e.g., 413 file too large)
      final code = e.response?.statusCode;
      final data = e.response?.data;
      final serverMsg = (data is Map && data['error'] is String)
          ? data['error']
          : (data is Map && data['message'] is String) ? data['message'] : null;
      throw StateError('HTTP ${code ?? 'ERR'}: ${serverMsg ?? e.message ?? 'Request failed'}');
    } finally {
      isUploading = false;
      isValidating = false;
      notifyListeners();
    }
  }

  void proceedToFace() {
    step = KycStep.face;
    notifyListeners();
  }

  void retakeDocument() {
    documentImage = null;
    ocr = null;
    mismatch = null;
    notifyListeners();
  }

  // ----------------------- Face ---------------------------------
  Future<void> setSelfieImage(PickedImage img) async {
    if (img.bytes.lengthInBytes < 60 * 1024) {
      throw StateError('Image too small/low quality');
    }
    selfieImage = img;
    face = null;
    notifyListeners();
  }

  Future<void> submitFaceForMatch({
    required String expectedName,
    required DateTime expectedDob,
    String? expectedIdNumber,
    String? expectedGender,
  }) async {
    if (selfieImage == null || documentImage == null) return;

    isUploading = true;
    isValidating = true;
    notifyListeners();

    try {
      final res = await api.faceVerify(
        frontBytes: documentImage!.bytes,
        frontMime: documentImage!.mime,
        selfieBytes: selfieImage!.bytes,
        selfieMime: selfieImage!.mime,
      );

      faceDecision = (res['decision']?.toString());
      faceThreshold = (res['threshold'] is num) ? (res['threshold'] as num).toDouble() : null;

      final matchScore = (res['similarity'] is num) ? (res['similarity'] as num).toDouble() : 0.0;
      final livenessScore = (res['livenessScore'] is num) ? (res['livenessScore'] as num).toDouble() : 0.0; // backend may not supply
      face = FaceMatchResult(matchScore: matchScore, livenessScore: livenessScore);
    } on DioException catch (e) {
      // Surface server error details (e.g., 413) to UI
      final code = e.response?.statusCode;
      final data = e.response?.data;
      final serverMsg = (data is Map && data['error'] is String)
          ? data['error']
          : (data is Map && data['message'] is String) ? data['message'] : null;
      throw StateError('HTTP ${code ?? 'ERR'}: ${serverMsg ?? e.message ?? 'Request failed'}');
    } finally {
      isUploading = false;
      isValidating = false;
      notifyListeners();
    }
  }

  /// Mark flow as completed (used by UI after terminal states).
  void complete() {
    step = KycStep.done;
    notifyListeners();
  }

  void reset() {
    step = KycStep.document;
    isValidating = false;
    isUploading = false;
    documentImage = null;
    selfieImage = null;
    ocr = null;
    mismatch = null;
    face = null;
    docDecision = null;
    faceDecision = null;
    faceThreshold = null;
    notifyListeners();
  }
}

DateTime? _tryParseDobFallbacks(String s) {
  // dd/MM/yyyy
  try {
    final parts = s.split('/');
    if (parts.length == 3) {
      final d = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final y = int.parse(parts[2]);
      return DateTime(y, m, d);
    }
  } catch (_) {}
  // d MMM yyyy
  try {
    final months = {
      'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,
      'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12
    };
    final p = s.trim().split(RegExp(r'\s+'));
    if (p.length == 3) {
      final d = int.parse(p[0]);
      final m = months[p[1].substring(0,3).toLowerCase()]!;
      final y = int.parse(p[2]);
      return DateTime(y, m, d);
    }
  } catch (_) {}
  return null;
}