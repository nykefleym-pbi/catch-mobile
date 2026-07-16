import 'package:flutter/foundation.dart';

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
  });

  final String id;
  final String label;
  final String emoji;

  /// Friendship gained when this treat is fed.
  final int bond;

  /// Happiness restored (clamped to 100 by the care state).
  final int happiness;
}

/// The v1 treat menu, ordered gentlest → most special.
const List<Treat> kTreats = [
  Treat(id: 'chicken', label: 'Chicken', emoji: '🍗', bond: 1, happiness: 4),
  Treat(id: 'tuna', label: 'Tuna', emoji: '🐟', bond: 2, happiness: 5),
  Treat(id: 'salmon', label: 'Salmon', emoji: '🍣', bond: 2, happiness: 7),
  Treat(id: 'catnip', label: 'Catnip', emoji: '🌿', bond: 1, happiness: 9),
  Treat(
    id: 'premium_treats',
    label: 'Premium Treats',
    emoji: '⭐',
    bond: 3,
    happiness: 6,
  ),
];
