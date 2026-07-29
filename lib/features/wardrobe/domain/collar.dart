import 'package:flutter/material.dart';

/// A cosmetic collar a cat can wear. Collars are earned by the bond you build
/// with a cat — kindness, never money or power (docs/product/04-game-systems.md)
/// — and are unlocked once that cat reaches the collar's bond tier.
@immutable
class Collar {
  const Collar({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    required this.unlockIndex,
    required this.unlockLabel,
  });

  final String id;
  final String label;
  final String emoji;

  /// A soft accent colour used for the wardrobe chip and the glow behind the
  /// sprite (we don't paint onto the pixel art itself).
  final Color color;

  /// The bond-level index (see [Bond]) at which this collar unlocks.
  final int unlockIndex;

  /// The human name of that bond tier, for the "Reach …" hint.
  final String unlockLabel;
}

/// The v1 collar catalogue, gentlest → most special. Unlock tiers mirror the
/// bond ladder in features/care (New Friend → Kindred Spirit).
const List<Collar> kCollars = [
  Collar(
    id: 'classic',
    label: 'Red bow',
    emoji: '🎀',
    color: Color(0xFFE07A5F),
    unlockIndex: 0,
    unlockLabel: 'the start',
  ),
  Collar(
    id: 'bell',
    label: 'Jingle bell',
    emoji: '🔔',
    color: Color(0xFFE7C077),
    unlockIndex: 1,
    unlockLabel: 'Familiar',
  ),
  Collar(
    id: 'flower',
    label: 'Flower',
    emoji: '🌸',
    color: Color(0xFFEFA58C),
    unlockIndex: 2,
    unlockLabel: 'Buddy',
  ),
  Collar(
    id: 'bandana',
    label: 'Bandana',
    emoji: '🧣',
    color: Color(0xFFA7C4A0),
    unlockIndex: 3,
    unlockLabel: 'Pal',
  ),
  Collar(
    id: 'star',
    label: 'Star tag',
    emoji: '⭐',
    color: Color(0xFFF6A96A),
    unlockIndex: 4,
    unlockLabel: 'Close Friend',
  ),
  Collar(
    id: 'crown',
    label: 'Little crown',
    emoji: '👑',
    color: Color(0xFFD9A03F),
    unlockIndex: 5,
    unlockLabel: 'Best Friend',
  ),
  Collar(
    id: 'heart',
    label: 'Heart charm',
    emoji: '💛',
    color: Color(0xFFC96448),
    unlockIndex: 6,
    unlockLabel: 'Kindred Spirit',
  ),
  // Seasonal collars (docs/roadmap p3e) — featured for a season, but permanent
  // additions to the catalogue like every other collar. No countdowns, no
  // expiry: earned by bond and yours to keep, always.
  Collar(
    id: 'blossom',
    label: 'Blossom',
    emoji: '🌷',
    color: Color(0xFFEFA0B8),
    unlockIndex: 1,
    unlockLabel: 'Familiar',
  ),
  Collar(
    id: 'sunflower',
    label: 'Sunflower',
    emoji: '🌻',
    color: Color(0xFFE7C077),
    unlockIndex: 2,
    unlockLabel: 'Buddy',
  ),
  Collar(
    id: 'maple',
    label: 'Maple leaf',
    emoji: '🍁',
    color: Color(0xFFC96448),
    unlockIndex: 2,
    unlockLabel: 'Buddy',
  ),
  Collar(
    id: 'snowflake',
    label: 'Snowflake',
    emoji: '❄️',
    color: Color(0xFFA9C7D8),
    unlockIndex: 3,
    unlockLabel: 'Pal',
  ),
];

/// Looks up a collar by id, or null (no collar / unknown id).
Collar? collarById(String? id) {
  if (id == null) return null;
  for (final c in kCollars) {
    if (c.id == id) return c;
  }
  return null;
}
