import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mlkit_cat_detector.dart';
import '../domain/cat_detector.dart';

/// The on-device cat detector. Built lazily (only when the capture flow needs
/// it) and closed when disposed so we don't hold the native ML Kit model open.
final catDetectorProvider = Provider<CatDetector>((ref) {
  final detector = MlKitCatDetector();
  ref.onDispose(detector.dispose);
  return detector;
});
