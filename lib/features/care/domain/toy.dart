import 'package:flutter/foundation.dart';

import '../../../core/assets/app_assets.dart';

/// A toy the player can play with in the drag-to-play mini-game. Play is
/// cosmetic + kind — it lifts happiness and the bond, never power
/// (docs/product/04-game-systems.md). [happiness] is how much the happiness
/// meter rises per playful drop; [emoji] is the little burst of joy that floats
/// up from the cat when the toy lands.
@immutable
class Toy {
  const Toy({
    required this.id,
    required this.label,
    required this.asset,
    required this.emoji,
    required this.happiness,
  });

  final String id;
  final String label;
  final String asset;

  /// The happy burst that rises from the cat when this toy is played with.
  final String emoji;

  /// Happiness-meter gain per playful drop.
  final int happiness;
}

/// The v1 toy shelf, gentlest → most exciting.
const List<Toy> kToys = [
  Toy(
    id: 'feather_teaser',
    label: 'Feather teaser',
    asset: AppAssets.featherTeaser,
    emoji: '💕',
    happiness: 18,
  ),
  Toy(
    id: 'toy_mouse',
    label: 'Toy mouse',
    asset: AppAssets.toyMouse,
    emoji: '😸',
    happiness: 20,
  ),
  Toy(
    id: 'laser_pointer',
    label: 'Laser pointer',
    asset: AppAssets.laserPointer,
    emoji: '⭐',
    happiness: 22,
  ),
  Toy(
    id: 'cat_tunnel',
    label: 'Tunnel',
    asset: AppAssets.catTunnel,
    emoji: '😻',
    happiness: 16,
  ),
  Toy(
    id: 'plushie',
    label: 'Plushie',
    asset: AppAssets.plushie,
    emoji: '💖',
    happiness: 16,
  ),
  Toy(
    id: 'discarded_box',
    label: 'Cardboard box',
    asset: AppAssets.discardedBox,
    emoji: '😹',
    happiness: 24,
  ),
];
