import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../domain/cat_detector.dart';

/// On-device cat detection backed by ML Kit image labeling (the bundled default
/// model). This is the free, private, offline gate that runs before we ever
/// spend a generation call — it keeps drawings, toys, screens, and dogs out of
/// the pipeline. See docs/architecture/07-ai-pipeline.md.
class MlKitCatDetector implements CatDetector {
  MlKitCatDetector({
    double catConfidenceThreshold = 0.7,
    ImageLabeler? labeler,
  })  : _catThreshold = catConfidenceThreshold,
        // Ask the labeler for anything it's at least a little sure about so we
        // can tell "a cat, faintly" apart from "definitely not a cat".
        _labeler = labeler ??
            ImageLabeler(
              options: ImageLabelerOptions(confidenceThreshold: 0.4),
            );

  final ImageLabeler _labeler;
  final double _catThreshold;

  /// Labels in ML Kit's default model that mean "a real cat".
  static const _catLabels = {'Cat'};

  @override
  Future<CatDetectionResult> analyze(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final labels = await _labeler.processImage(input);

    ImageLabel? cat;
    for (final label in labels) {
      if (_catLabels.contains(label.label)) {
        cat = label;
        break;
      }
    }

    final confidence = cat?.confidence ?? 0.0;
    final isCat = confidence >= _catThreshold;

    return CatDetectionResult(
      isCat: isCat,
      confidence: confidence,
      // Quality gating (blur/brightness/size) is a later refinement; for now a
      // confident cat detection is enough to proceed.
      passedQualityGate: isCat,
      rejectionReason: isCat ? null : _reason(cat != null),
    );
  }

  String _reason(bool sawFaintCat) {
    if (sawFaintCat) {
      return "We think there's a cat, but we're not sure. "
          'Get a little closer and try again.';
    }
    return "Hmm, we couldn't spot a cat there. "
        'Point the camera at a real cat and try again.';
  }

  /// Release the native detector. Call from provider disposal.
  Future<void> dispose() => _labeler.close();
}
