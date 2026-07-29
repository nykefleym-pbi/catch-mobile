import 'package:flutter/foundation.dart';

import '../../../core/assets/app_assets.dart';

/// A food the player can feed a cat. Mirrors the seeded `items` catalog
/// (supabase/migrations/0002) — different treats deepen the bond by different
/// amounts and lift happiness by different amounts, so feeding is a little
/// choice rather than one flat button.
@immutable
class Treat {
  const Treat({
    required this.id,
    required this.label,
    required this.emoji,
    required this.bond,
    required this.happiness,
    this.asset,
  });

  final String id;
  final String label;
  final String emoji;

  /// Optional illustrated art ([AppAssets] path). Falls back to [emoji] where
  /// null so a treat always renders.
  final String? asset;

  /// Friendship gained when this treat is fed.
  final int bond;

  /// Happiness restored (clamped to 100 by the care state).
  final int happiness;
}

/// The v1 treat menu, ordered gentlest → most special.
const List<Treat> kTreats = [
  Treat(
    id: 'milk',
    label: 'Milk',
    emoji: '🥛',
    bond: 1,
    happiness: 3,
    asset: AppAssets.milk,
  ),
  Treat(
    id: 'chicken',
    label: 'Kibbles',
    emoji: '🍗',
    bond: 1,
    happiness: 4,
    asset: AppAssets.kibbles,
  ),
  Treat(
    id: 'tuna',
    label: 'Fish',
    emoji: '🐟',
    bond: 2,
    happiness: 5,
    asset: AppAssets.fish,
  ),
  Treat(
    id: 'salmon',
    label: 'Canned food',
    emoji: '🍣',
    bond: 2,
    happiness: 7,
    asset: AppAssets.cannedFood,
  ),
  Treat(
    id: 'catnip',
    label: 'Catnip',
    emoji: '🌿',
    bond: 1,
    happiness: 9,
    asset: AppAssets.catnip,
  ),
  Treat(
    id: 'premium_treats',
    label: 'Treats',
    emoji: '⭐',
    bond: 3,
    happiness: 6,
    asset: AppAssets.treats,
  ),
];
