import 'package:flutter/foundation.dart';

import '../../../core/assets/app_assets.dart';

/// The visual flourish a grooming tool makes when it lands on the cat.
enum GroomEffect {
  /// Rising soap bubbles (shampoo, soap).
  bubbles,

  /// Little clipped/filed bits that fall away (nail clipper, nail file).
  nailBits,

  /// A rising sparkle shine (toothbrush).
  shine,

  /// Soft tufts of fur drifting down (shaver).
  fur,
}

extension GroomEffectView on GroomEffect {
  /// The particle glyph for this effect.
  String get glyph => switch (this) {
        GroomEffect.bubbles => '🫧',
        GroomEffect.nailBits => '✦',
        GroomEffect.shine => '✨',
        GroomEffect.fur => '🍂',
      };

  /// Whether the particle rises (true) or falls (false).
  bool get rises => switch (this) {
        GroomEffect.bubbles => true,
        GroomEffect.shine => true,
        GroomEffect.nailBits => false,
        GroomEffect.fur => false,
      };
}

/// A grooming tool in the drag-to-groom mini-game. Grooming is cosmetic + kind —
/// it freshens hygiene and deepens the bond, never power. [hygiene] is how much
/// the cleanliness meter rises per drop.
@immutable
class GroomTool {
  const GroomTool({
    required this.id,
    required this.label,
    required this.asset,
    required this.effect,
    required this.caption,
    required this.hygiene,
  });

  final String id;
  final String label;
  final String asset;
  final GroomEffect effect;

  /// A warm line shown when this tool is used.
  final String caption;

  /// Cleanliness-meter gain per drop.
  final int hygiene;
}

/// The v1 grooming kit.
const List<GroomTool> kGroomTools = [
  GroomTool(
    id: 'shampoo',
    label: 'Shampoo',
    asset: AppAssets.shampoo,
    effect: GroomEffect.bubbles,
    caption: 'Sudsy and warm — so many bubbles!',
    hygiene: 20,
  ),
  GroomTool(
    id: 'soap',
    label: 'Soap',
    asset: AppAssets.soap,
    effect: GroomEffect.bubbles,
    caption: 'A gentle lather — squeaky clean.',
    hygiene: 18,
  ),
  GroomTool(
    id: 'nail_clipper',
    label: 'Nail clipper',
    asset: AppAssets.nailClipper,
    effect: GroomEffect.nailBits,
    caption: 'A tiny manicure — so dignified.',
    hygiene: 16,
  ),
  GroomTool(
    id: 'nail_file',
    label: 'Nail file',
    asset: AppAssets.nailFile,
    effect: GroomEffect.nailBits,
    caption: 'Smoothing the edges — nice and neat.',
    hygiene: 14,
  ),
  GroomTool(
    id: 'toothbrush',
    label: 'Toothbrush',
    asset: AppAssets.toothbrush,
    effect: GroomEffect.shine,
    caption: 'Fresh minty smile — sparkling!',
    hygiene: 16,
  ),
  GroomTool(
    id: 'shaver',
    label: 'Shaver',
    asset: AppAssets.shaver,
    effect: GroomEffect.fur,
    caption: 'A tidy trim — soft tufts drift away.',
    hygiene: 18,
  ),
];
