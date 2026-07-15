import 'dart:typed_data';

/// Outcome of the on-device "is this a real cat?" + quality gate that runs
/// before we ever spend a (free-tier, but rate-limited) generation call.
/// See docs/architecture/07-ai-pipeline.md.
class CatDetectionResult {
  const CatDetectionResult({
    required this.isCat,
    required this.confidence,
    required this.passedQualityGate,
    this.rejectionReason,
  });

  final bool isCat;

  /// 0.0–1.0 classifier confidence that the subject is a real cat.
  final double confidence;

  /// Whether the image is sharp/bright/large enough to be worth generating from.
  final bool passedQualityGate;

  /// Friendly, non-punitive reason shown to the player when we reject a photo
  /// (e.g. "That looks like a drawing" / "Too blurry — try again").
  final String? rejectionReason;

  bool get accepted => isCat && passedQualityGate;
}

/// On-device cat detection contract. The Phase 1 implementation is backed by
/// Google ML Kit / TFLite; keeping it behind an interface lets us swap the
/// model and unit-test the capture flow with a fake.
abstract interface class CatDetector {
  Future<CatDetectionResult> analyze(Uint8List imageBytes);
}
