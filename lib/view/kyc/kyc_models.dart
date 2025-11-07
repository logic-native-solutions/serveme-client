/// KYC (Know Your Customer) — Models & simple types.
/// These are UI-agnostic and safe to reuse in other layers.
library;

import 'dart:typed_data';

/// What step of the flow the user is on.
enum KycStep { document, face, done }

/// Result of server's OCR over the uploaded ID.
class OcrResult {
  final String? name;
  final DateTime? dob;
  final String? idNumber;

  /// Quality checks reported by server/computer-vision.
  final bool cornersOk;
  final bool blurOk;
  final bool glareOk;

  const OcrResult({
    this.name,
    this.dob,
    this.idNumber,
    this.cornersOk = true,
    this.blurOk = true,
    this.glareOk = true,
  });

  bool get isQualityOk => cornersOk && blurOk && glareOk;
}

/// Mismatch information returned by server (e.g., name/dob mismatch).
class MismatchInfo {
  final List<String> fields; // e.g. ['Name', 'Date of Birth']
  const MismatchInfo(this.fields);
  bool get hasAny => fields.isNotEmpty;
}

/// Result of selfie + liveness + face match.
class FaceMatchResult {
  final double matchScore;     // 0..1
  final double livenessScore;  // 0..1
  const FaceMatchResult({required this.matchScore, required this.livenessScore});

  bool get passed => matchScore >= 0.72 && livenessScore >= 0.60; // example thresholds
}

/// Local file we picked (image bytes + mime).
class PickedImage {
  final Uint8List bytes;
  final String mime; // 'image/jpeg' | 'image/png' etc.
  PickedImage(this.bytes, this.mime);
}