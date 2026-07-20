import 'package:flutter/foundation.dart';

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
  });

  final String id;
  final String label;
  final String emoji;

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
  ),
  DecorItem(
    id: 'bowl',
    label: 'Food bowl',
    emoji: '🥣',
    unlockIndex: 0,
    unlockLabel: 'the start',
  ),
  DecorItem(
    id: 'plant',
    label: 'Plant',
    emoji: '🪴',
    unlockIndex: 1,
    unlockLabel: 'Familiar',
  ),
  DecorItem(
    id: 'yarn',
    label: 'Yarn',
    emoji: '🧶',
    unlockIndex: 1,
    unlockLabel: 'Familiar',
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
