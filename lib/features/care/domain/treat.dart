import 'dart:ui' show Color;

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
    required this.color,
    this.liquid = false,
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

  /// The food's dominant colour — used to tint the bits that fall while it's
  /// being eaten (drops for a liquid, crumbs for a solid).
  final Color color;

  /// Whether this food is a liquid (milk) — falling bits are round drops rather
  /// than crumbly semicircles.
  final bool liquid;
}

/// The v1 treat menu, ordered gentlest → most special.
const List<Treat> kTreats = [
  Treat(
    id: 'milk',
    label: 'Milk',
    emoji: '🥛',
    bond: 1,
    happiness: 3,
    color: Color(0xFFF3EFE6),
    liquid: true,
    asset: AppAssets.milk,
  ),
  Treat(
    id: 'chicken',
    label: 'Kibbles',
    emoji: '🍗',
    bond: 1,
    happiness: 4,
    color: Color(0xFFC98A4B),
    asset: AppAssets.kibbles,
  ),
  Treat(
    id: 'tuna',
    label: 'Fish',
    emoji: '🐟',
    bond: 2,
    happiness: 5,
    color: Color(0xFFEBA9A0),
    asset: AppAssets.fish,
  ),
  Treat(
    id: 'salmon',
    label: 'Canned food',
    emoji: '🍣',
    bond: 2,
    happiness: 7,
    color: Color(0xFFD98A5B),
    asset: AppAssets.cannedFood,
  ),
  Treat(
    id: 'catnip',
    label: 'Catnip',
    emoji: '🌿',
    bond: 1,
    happiness: 9,
    color: Color(0xFF9BBE6A),
    asset: AppAssets.catnip,
  ),
  Treat(
    id: 'cat_grass',
    label: 'Cat grass',
    emoji: '🌱',
    bond: 1,
    happiness: 6,
    color: Color(0xFF8FB56A),
    asset: AppAssets.catGrass,
  ),
  Treat(
    id: 'steamed_carrot_squash',
    label: 'Carrot & squash',
    emoji: '🥕',
    bond: 2,
    happiness: 6,
    color: Color(0xFFE39A4A),
    asset: AppAssets.steamedCarrotAndSquash,
  ),
  Treat(
    id: 'egg',
    label: 'Egg',
    emoji: '🥚',
    bond: 2,
    happiness: 5,
    color: Color(0xFFF2D9A0),
    asset: AppAssets.egg,
  ),
  Treat(
    id: 'premium_treats',
    label: 'Treats',
    emoji: '⭐',
    bond: 3,
    happiness: 6,
    color: Color(0xFFCDA349),
    asset: AppAssets.treats,
  ),
];
