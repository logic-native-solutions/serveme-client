import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'kyc_controller.dart';
import 'kyc_models.dart';

// Simple error dialog used across the KYC flow
Future<void> _showError(BuildContext context, String title, String message) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
      ],
    ),
  );
}
class KycFlowScreen extends StatefulWidget {
  final String expectedName;           // for server side field match
  final DateTime expectedDob;
  final String profileAvatarAsset;     // same avatar as Profile
  final String? expectedIdNumber;      // optional: used for mismatch display
  final String? expectedGender;        // optional: 'M' or 'F'

  const KycFlowScreen({
    super.key,
    required this.expectedName,
    required this.expectedDob,
    required this.profileAvatarAsset,
    this.expectedIdNumber,
    this.expectedGender,
  });

  @override
  State<KycFlowScreen> createState() => _KycFlowScreenState();
}

class _KycFlowScreenState extends State<KycFlowScreen> {
  late final KycController c;

  @override
  void initState() {
    super.initState();
    c = KycController();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        switch (c.step) {
          case KycStep.document:
            return _DocScreen(
              c: c,
              expectedName: widget.expectedName,
              expectedDob: widget.expectedDob,
              expectedIdNumber: widget.expectedIdNumber,
              expectedGender: widget.expectedGender,
            );
          case KycStep.face:
            return _FaceScreen(
              c: c,
              avatarAsset: widget.profileAvatarAsset,
              expectedName: widget.expectedName,
              expectedDob: widget.expectedDob,
              expectedIdNumber: widget.expectedIdNumber,
              expectedGender: widget.expectedGender,
            );
          case KycStep.done:
            return _DoneScreen(onClose: () => Navigator.pop(context, true));
        }
      },
    );
  }
}

/// ------------------ DOCUMENT: live capture only ------------------
/// Tapping the box opens the CAMERA (no gallery).
class _DocScreen extends StatelessWidget {
  final KycController c;
  final String expectedName;
  final DateTime expectedDob;
  final String? expectedIdNumber;
  final String? expectedGender;
  const _DocScreen({
    required this.c,
    required this.expectedName,
    required this.expectedDob,
    this.expectedIdNumber,
    this.expectedGender,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const edge = EdgeInsets.symmetric(horizontal: 20, vertical: 12);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Identity Verification',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: t.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: edge,
            child: Text('Please take a live photo of your ID document.', style: t.textTheme.bodyLarge),
          ),

          // Dashed card; taps open the CAMERA only
          Padding(
            padding: edge,
            child: _DashedUploadBox(
              child: _UploadInner(
                hasPicked: c.documentImage != null,
                onTap: () => _capture(context, (img) async {
                  await c.setDocumentImage(img);
                }),
                label: 'Tap to capture your ID (camera only)',
              ),
            ),
          ),

          // Checklist
          Padding(
            padding: edge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Checklist(text: 'Ensure all four corners are visible.'),
                _Checklist(text: 'Avoid blur—hold steady and fill the frame.'),
                _Checklist(text: 'No glare or reflections on the plastic.'),
              ],
            ),
          ),

          // Continue → sends to Arya for OCR + field match
          Padding(
            padding: edge,
            child: FilledButton(
              onPressed: (c.documentImage != null && !c.isUploading)
                  ? () async {
                try {
                  await c.submitDocumentForOcr(
                    expectedName: expectedName,
                    expectedDob: expectedDob,
                    expectedIdNumber: expectedIdNumber,
                    expectedGender: expectedGender,
                  );
                } catch (e) {
                  final msg = e.toString().toLowerCase();
                  if (msg.contains('413') || msg.contains('payload too large') || msg.contains('file too large')) {
                    await _showError(
                      context,
                      'Image too large',
                      'The uploaded image exceeds the 8 MB limit. Please retake the photo a little farther away.',
                    );
                    return;
                  }
                  await _showError(
                    context,
                    'Upload failed',
                    'We couldn’t validate your ID right now.\n\nDetails: $e',
                  );
                  return;
                }

                if (c.mismatch != null && c.mismatch!.hasAny) {
                  await showModalBottomSheet(
                    context: context,
                    builder: (_) => _MismatchSheet(fields: c.mismatch!.fields),
                  );
                  return;
                }

                // Branch on backend decision
                final decision = c.docDecision?.toUpperCase();
                if (decision == 'AUTO_PASS') {
                  final ok = await showModalBottomSheet<bool>(
                    context: context,
                    builder: (_) => const _DocSuccessSheet(),
                  );
                  if (ok == true) c.proceedToFace();
                } else if (decision == 'MANUAL_REVIEW') {
                  final ok = await showModalBottomSheet<bool>(
                    context: context,
                    builder: (_) => const _ManualReviewSheet(
                      title: 'Manual Review',
                      message:
                      'Thanks! Your ID was received and may require manual review. We’ll proceed to the next step now.',
                    ),
                  );
                  if (ok == true) c.proceedToFace();
                } else if (c.ocr != null && c.ocr!.isQualityOk) {
                  // Fallback if decision missing: treat as success
                  final ok = await showModalBottomSheet<bool>(
                    context: context,
                    builder: (_) => const _DocSuccessSheet(),
                  );
                  if (ok == true) c.proceedToFace();
                }
              }
                  : null,
              child: c.isValidating
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the CAMERA and returns bytes (no gallery fallback).
  Future<void> _capture(
    BuildContext context,
    Future<void> Function(PickedImage) onPicked,
  ) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,        // <- camera only
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,                  // reduce size, keep quality
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();

    // Prevent >8MB images to avoid backend 413
    if (bytes.lengthInBytes > 8 * 1024 * 1024) {
      await _showError(
        context,
        'Image too large',
        'Please retake the photo a little farther away. Max size is 8 MB.',
      );
      return;
    }

    await onPicked(PickedImage(bytes, _mime(file.path)));
  }
}

/// ------------------ FACE: live selfie with ID --------------------
class _FaceScreen extends StatelessWidget {
  final KycController c;
  final String avatarAsset;
  final String expectedName;
  final DateTime expectedDob;
  final String? expectedIdNumber;
  final String? expectedGender;
  const _FaceScreen({
    required this.c,
    required this.avatarAsset,
    required this.expectedName,
    required this.expectedDob,
    this.expectedIdNumber,
    this.expectedGender,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const edge = EdgeInsets.symmetric(horizontal: 20, vertical: 12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        backgroundColor: t.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: edge,
            child: Text('Take a selfie holding your ID next to your face.', style: t.textTheme.bodyLarge),
          ),

          // Large circular placeholder using the SAME avatar as Profile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.colorScheme.surfaceContainerHighest),
                child: Center(
                  child: c.selfieImage == null
                      ? CircleAvatar(radius: 64, backgroundImage: AssetImage(avatarAsset))
                      : ClipOval(child: Image.memory(c.selfieImage!.bytes, fit: BoxFit.cover)),
                ),
              ),
            ),
          ),

          // Tips
          Padding(
            padding: edge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Checklist(text: 'Well-lit, plain background if possible.'),
                _Checklist(text: 'Remove hats/glasses.'),
                _Checklist(text: 'Hold your ID clearly by your face.'),
              ],
            ),
          ),

          // Capture selfie (camera only)
          Padding(
            padding: edge,
            child: FilledButton.tonal(
              onPressed: c.isUploading ? null : () => _captureSelfie(context),
              child: const Text('Take Selfie'),
            ),
          ),

          // Proceed → Arya face match + liveness
          Padding(
            padding: edge,
            child: FilledButton(
              onPressed: (c.selfieImage != null && !c.isUploading)
                  ? () async {
                try {
                  await c.submitFaceForMatch(
                    expectedName: expectedName,
                    expectedDob: expectedDob,
                    expectedIdNumber: expectedIdNumber,
                    expectedGender: expectedGender,
                  );
                } catch (e) {
                  final msg = e.toString().toLowerCase();
                  if (msg.contains('413') || msg.contains('payload too large') || msg.contains('file too large')) {
                    await _showError(
                      context,
                      'Image too large',
                      'The uploaded image exceeds the 8 MB limit. Please retake the selfie a little farther away.',
                    );
                    return;
                  }
                  await _showError(
                    context,
                    'Upload failed',
                    'We couldn’t verify your selfie right now.\n\nDetails: $e',
                  );
                  return;
                }

                final decision = c.faceDecision?.toUpperCase();
                if (decision == 'AUTO_PASS') {
                  await showModalBottomSheet(
                    context: context,
                    builder: (_) => const _FacePassSheet(),
                  );
                  c.complete();
                } else if (decision == 'MANUAL_REVIEW') {
                  final sim = c.face?.matchScore;
                  final thr = c.faceThreshold;
                  final msg2 = (sim != null && thr != null)
                      ? 'Your selfie was received and may require manual review.\nSimilarity: ${sim.toStringAsFixed(2)} (threshold ${thr.toStringAsFixed(2)}).'
                      : 'Your selfie was received and may require manual review.';
                  await showModalBottomSheet(
                    context: context,
                    builder: (_) => _ManualReviewSheet(title: 'Manual Review', message: msg2),
                  );
                  c.complete();
                } else if (c.face != null && c.face!.passed) {
                  await showModalBottomSheet(
                    context: context,
                    builder: (_) => const _FacePassSheet(),
                  );
                  c.complete();
                } else {
                  await showModalBottomSheet(
                    context: context,
                    builder: (_) => const _FaceFailSheet(),
                  );
                }
              }
                  : null,
              child: c.isValidating
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Proceed'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureSelfie(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,          // <- camera only
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (bytes.lengthInBytes > 8 * 1024 * 1024) {
      await _showError(
        context,
        'Image too large',
        'Please retake the selfie a little farther away. Max size is 8 MB.',
      );
      return;
    }

    await c.setSelfieImage(PickedImage(bytes, _mime(file.path)));
  }
}

/// ------------------ Shared small widgets ------------------------
class _Checklist extends StatelessWidget {
  final String text;
  const _Checklist({required this.text});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(Icons.check_circle, color: t.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: t.textTheme.bodyMedium)),
      ]),
    );
  }
}

class _DashedUploadBox extends StatelessWidget {
  final Widget child;
  const _DashedUploadBox({required this.child});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.colorScheme.outline, width: 1.6),
      ),
      child: child,
    );
  }
}

class _UploadInner extends StatelessWidget {
  final bool hasPicked;
  final VoidCallback onTap;
  final String label;
  const _UploadInner({required this.hasPicked, required this.onTap, required this.label});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(hasPicked ? Icons.check_circle : Icons.photo_camera, size: 44, color: t.colorScheme.primary),
          const SizedBox(height: 10),
          Text(hasPicked ? 'Captured • Ready to validate' : label, style: t.textTheme.bodyLarge, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// Bottom sheets — mapped to your design language
class _MismatchSheet extends StatelessWidget {
  final List<String> fields;
  const _MismatchSheet({required this.fields});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return _Sheet(
      icon: Icons.close,
      color: t.colorScheme.error,
      title: 'ID Information Mismatch',
      message: 'The following information does not match:\n• ${fields.join('\n• ')}',
      primary: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Retake')),
      secondary: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
    );
  }
}

class _DocSuccessSheet extends StatelessWidget {
  const _DocSuccessSheet();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return _Sheet(
      icon: Icons.check_circle,
      color: t.colorScheme.primary,
      title: 'ID Verification Successful',
      message: 'Your ID has been successfully validated.',
      primary: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed')),
    );
  }
}

class _FaceFailSheet extends StatelessWidget {
  const _FaceFailSheet();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return _Sheet(
      icon: Icons.close,
      color: t.colorScheme.error,
      title: 'Face Verification Failed',
      message: 'We couldn’t verify your selfie. Please retake.',
      primary: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Retake')),
      secondary: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
    );
  }
}

class _FacePassSheet extends StatelessWidget {
  const _FacePassSheet();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return _Sheet(
      icon: Icons.check_circle,
      color: t.colorScheme.primary,
      title: 'Face Verification Passed',
      message: 'Your selfie was verified successfully.',
      primary: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed')),
    );
  }
}

class _Sheet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget primary;
  final Widget? secondary;
  const _Sheet({required this.icon, required this.color, required this.title, required this.message, required this.primary, this.secondary});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(children: [
          if (secondary != null) Expanded(child: secondary!),
          if (secondary != null) const SizedBox(width: 12),
          Expanded(child: primary),
        ]),
      ]),
    );
  }
}

class _DoneScreen extends StatelessWidget {
  final VoidCallback onClose;
  const _DoneScreen({required this.onClose});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified, size: 72, color: t.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Verification Complete', style: t.textTheme.headlineSmall),
          const SizedBox(height: 12),
          FilledButton(onPressed: onClose, child: const Text('Close')),
        ]),
      ),
    );
  }
}

String _mime(String path) => path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
// Manual Review Sheet
class _ManualReviewSheet extends StatelessWidget {
  final String title;
  final String message;
  const _ManualReviewSheet({required this.title, required this.message});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return _Sheet(
      icon: Icons.hourglass_bottom,
      color: t.colorScheme.tertiary,
      title: title,
      message: message,
      primary: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed')),
    );
  }
}