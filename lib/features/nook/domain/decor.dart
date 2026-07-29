import 'package:flutter/foundation.dart';

import '../../../core/assets/app_assets.dart';

/// A piece of decor the player can place in a cat's nook. Decor is cosmetic
/// only — never power — and unlocks with the bond you build with that cat
/// (docs/product/04-game-systems.md).
@immutable
class DecorItem {
  const DecorItem({
    required this.id,
    required this.label,
    required this.emoji,
    required this.unlockIndex,
    required this.unlockLabel,
    this.asset,
  });

  final String id;
  final String label;
  final String emoji;

  /// Optional illustrated art ([AppAssets] path); [emoji] is the fallback.
  final String? asset;

  /// Bond-level index (see [Bond]) at which this decor unlocks.
  final int unlockIndex;

  /// Human name of that bond tier, for the "Reach …" hint.
  final String unlockLabel;
}

/// The v1 decor catalogue, gentlest → most special.
const List<DecorItem> kDecor = [
  DecorItem(
    id: 'bed',
    label: 'Cat bed',
    emoji: '🛏️',
    unlockIndex: 0,
    unlockLabel: 'the start',
    asset: AppAssets.catBed,
  ),
  DecorItem(
    id: 'bowl',
    label: 'Food bowl',
    emoji: '🥣',
    unlockIndex: 0,
    unlockLabel: 'the start',
    asset: AppAssets.foodBowl,
  ),
  DecorItem(
    id: 'plant',
    label: 'Cat grass',
    emoji: '🪴',
    unlockIndex: 1,
    unlockLabel: 'Familiar',
    asset: AppAssets.catGrass,
  ),
  DecorItem(
    id: 'yarn',
    label: 'Yarn',
    emoji: '🧶',
    unlockIndex: 1,
    unlockLabel: 'Familiar',
    asset: AppAssets.ballOfYarn,
  ),
  // Illustrated furniture (from the Cat Items art set), bond-gated like the
  // rest — cosmetic only, never power.
  DecorItem(
    id: 'scratch_post',
    label: 'Scratch post',
    emoji: '🪵',
    unlockIndex: 1,
    unlockLabel: 'Familiar',
    asset: AppAssets.scratchPost,
  ),
  DecorItem(
    id: 'water_fountain',
    label: 'Water fountain',
    emoji: '⛲',
    unlockIndex: 2,
    unlockLabel: 'Buddy',
    asset: AppAssets.waterFountain,
  ),
  DecorItem(
    id: 'cat_tunnel',
    label: 'Tunnel',
    emoji: '🕳️',
    unlockIndex: 2,
    unlockLabel: 'Buddy',
    asset: AppAssets.catTunnel,
  ),
  DecorItem(
    id: 'cat_house',
    label: 'Cat house',
    emoji: '🏠',
    unlockIndex: 3,
    unlockLabel: 'Pal',
    asset: AppAssets.catHouse,
  ),
  DecorItem(
    id: 'hammock',
    label: 'Hammock',
    emoji: '🛌',
    unlockIndex: 4,
    unlockLabel: 'Close Friend',
    asset: AppAssets.hangingHammock,
  ),
  DecorItem(
    id: 'cat_tree',
    label: 'Cat tree',
    emoji: '🌳',
    unlockIndex: 5,
    unlockLabel: 'Best Friend',
    asset: AppAssets.catTree,
  ),
  DecorItem(
    id: 'window',
    label: 'Window',
    emoji: '🪟',
    unlockIndex: 2,
    unlockLabel: 'Buddy',
  ),
  DecorItem(
    id: 'lamp',
    label: 'Lamp',
    emoji: '🪔',
    unlockIndex: 3,
    unlockLabel: 'Pal',
  ),
  DecorItem(
    id: 'sofa',
    label: 'Sofa',
    emoji: '🛋️',
    unlockIndex: 4,
    unlockLabel: 'Close Friend',
  ),
  DecorItem(
    id: 'picture',
    label: 'Picture',
    emoji: '🖼️',
    unlockIndex: 5,
    unlockLabel: 'Best Friend',
  ),
  // Seasonal decor (docs/roadmap p3e) — featured for a season, but permanent
  // additions to the catalogue like every other piece. No countdowns, no
  // expiry: earned by bond and yours to keep, always.
  DecorItem(
    id: 'tulips',
    label: 'Tulips',
    emoji: '🌷',
    unlockIndex: 1,
    unlockLabel: 'Familiar',
  ),
  DecorItem(
    id: 'sun-lamp',
    label: 'Sun lamp',
    emoji: '☀️',
    unlockIndex: 2,
    unlockLabel: 'Buddy',
  ),
  DecorItem(
    id: 'pumpkin',
    label: 'Pumpkin',
    emoji: '🎃',
    unlockIndex: 2,
    unlockLabel: 'Buddy',
  ),
  DecorItem(
    id: 'snow-globe',
    label: 'Snow globe',
    emoji: '🔮',
    unlockIndex: 3,
    unlockLabel: 'Pal',
  ),
];

DecorItem? decorById(String id) {
  for (final d in kDecor) {
    if (d.id == id) return d;
  }
  return null;
}

/// One placed piece of decor in a nook. Position is stored as 0..1 fractions of
/// the room so it survives any screen size; [rot] is in quarter-turns (0–3).
class PlacedDecor {
  PlacedDecor({
    required this.instanceId,
    required this.itemId,
    required this.x,
    required this.y,
    this.rot = 0,
  });

  final String instanceId;
  final String itemId;
  double x;
  double y;
  int rot;

  Map<String, dynamic> toJson() => {
        'iid': instanceId,
        'item': itemId,
        'x': x,
        'y': y,
        'rot': rot,
      };

  factory PlacedDecor.fromJson(Map<String, dynamic> j) => PlacedDecor(
        instanceId: j['iid'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        itemId: j['item'] as String? ?? '',
        x: (j['x'] as num?)?.toDouble() ?? 0.5,
        y: (j['y'] as num?)?.toDouble() ?? 0.5,
        rot: (j['rot'] as num?)?.toInt() ?? 0,
      );
}
