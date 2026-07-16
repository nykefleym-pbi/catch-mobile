import 'package:flutter/foundation.dart';

/// A friendship tier a cat can reach as the player cares for it. Bond only ever
/// grows — it's the warm, permanent record of your time together (kindness
/// earns rank, per the product vision), unlike the gently-decaying daily needs.
@immutable
class BondLevel {
  const BondLevel(this.threshold, this.name);

  final int threshold;
  final String name;
}

const List<BondLevel> _bondLevels = [
  BondLevel(0, 'New Friend'),
  BondLevel(6, 'Familiar'),
  BondLevel(15, 'Buddy'),
  BondLevel(30, 'Pal'),
  BondLevel(50, 'Close Friend'),
  BondLevel(80, 'Best Friend'),
  BondLevel(120, 'Kindred Spirit'),
];

/// Pure helpers for turning a raw friendship score into a tier + progress.
class Bond {
  const Bond._();

  static int levelIndexFor(int points) {
    var index = 0;
    for (var i = 0; i < _bondLevels.length; i++) {
      if (points >= _bondLevels[i].threshold) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  static String labelFor(int points) => _bondLevels[levelIndexFor(points)].name;

  static bool isMax(int points) => levelIndexFor(points) >= _bondLevels.length - 1;

  /// Progress (0–1) within the current tier toward the next; full at max tier.
  static double progressFor(int points) {
    final i = levelIndexFor(points);
    if (i >= _bondLevels.length - 1) return 1;
    final current = _bondLevels[i].threshold;
    final next = _bondLevels[i + 1].threshold;
    return ((points - current) / (next - current)).clamp(0.0, 1.0);
  }
}

/// A cat's care state — hunger + happiness (daily needs) plus [friendship] (the
/// permanent bond) — mirroring the `care_state` row and `cats.friendship_level`
/// (docs/architecture/06-data-model.md).
///
/// Need decay is deliberately **gentle and non-punitive**: values drift down
/// slowly since [lastUpdated] and are floored at [_floor] so a cat is never left
/// miserable. There is no server cron; the client computes the decayed value on
/// read and writes a fresh snapshot whenever the player feeds or plays. Feeding
/// and playing also raise [friendship], which never decays — so every
/// interaction is rewarding even when the needs are already full.
@immutable
class CareState {
  const CareState({
    required this.catId,
    required this.hunger,
    required this.happiness,
    required this.mood,
    required this.lastUpdated,
    this.friendship = 0,
  });

  final String catId;

  /// Values as last written to the database (0–100). Use [currentHunger] /
  /// [currentHappiness] for display so the decay-since-[lastUpdated] shows.
  final int hunger;
  final int happiness;
  final String mood;
  final DateTime lastUpdated;

  /// The permanent bond score (from `cats.friendship_level`). Grows with care.
  final int friendship;

  // ~[_decayPerHour] points/hour, floored at [_floor] so needs never bottom out.
  static const int _decayPerHour = 3;
  static const int _floor = 30;

  int get currentHunger => _decayed(hunger);
  int get currentHappiness => _decayed(happiness);

  int _decayed(int base) {
    final hours = DateTime.now().difference(lastUpdated).inMinutes / 60.0;
    if (hours <= 0) return base.clamp(0, 100);
    final decayed = (base - _decayPerHour * hours).round();
    return decayed.clamp(_floor, 100);
  }

  /// A friendly mood label derived from the *current* (decayed) needs, so the
  /// display feels alive even between writes.
  String get currentMood {
    final avg = (currentHunger + currentHappiness) / 2;
    if (avg >= 85) return 'Blissful';
    if (avg >= 65) return 'Content';
    if (avg >= 45) return 'Restless';
    return 'Needy';
  }

  String get bondLabel => Bond.labelFor(friendship);
  double get bondProgress => Bond.progressFor(friendship);
  bool get bondIsMax => Bond.isMax(friendship);

  /// A brand-new cat starts perfectly content (the row is created at capture).
  factory CareState.initial(String catId, {int friendship = 0}) => CareState(
        catId: catId,
        hunger: 100,
        happiness: 100,
        mood: 'content',
        lastUpdated: DateTime.now(),
        friendship: friendship,
      );

  factory CareState.fromMap(Map<String, dynamic> map, {int friendship = 0}) =>
      CareState(
        catId: map['cat_id'] as String,
        hunger: (map['hunger'] as num?)?.toInt() ?? 100,
        happiness: (map['happiness'] as num?)?.toInt() ?? 100,
        mood: (map['mood'] as String?)?.trim().isNotEmpty == true
            ? map['mood'] as String
            : 'content',
        lastUpdated:
            DateTime.tryParse(map['last_updated'] as String? ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
        friendship: friendship,
      );

  /// The `care_state` row payload for an upsert (friendship lives on `cats` and
  /// is persisted separately). [profileId] is required by RLS on insert.
  Map<String, dynamic> toRow(String? profileId) => {
        'cat_id': catId,
        if (profileId != null) 'profile_id': profileId,
        'hunger': hunger,
        'happiness': happiness,
        'mood': mood,
        'last_updated': lastUpdated.toUtc().toIso8601String(),
      };

  CareState copyWith({
    int? hunger,
    int? happiness,
    String? mood,
    DateTime? lastUpdated,
    int? friendship,
  }) =>
      CareState(
        catId: catId,
        hunger: hunger ?? this.hunger,
        happiness: happiness ?? this.happiness,
        mood: mood ?? this.mood,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        friendship: friendship ?? this.friendship,
      );

  /// Feeding fills hunger, lifts spirits a little, and deepens the bond (+1).
  /// Built from the *current* decayed values so it's fair no matter how long
  /// it's been.
  CareState fed() {
    final next = CareState(
      catId: catId,
      hunger: 100,
      happiness: (currentHappiness + 5).clamp(0, 100),
      mood: mood,
      lastUpdated: DateTime.now(),
      friendship: friendship + 1,
    );
    return next.copyWith(mood: next.currentMood.toLowerCase());
  }

  /// Playing tops up happiness and bonds a little more than feeding (+2).
  CareState played() {
    final next = CareState(
      catId: catId,
      hunger: currentHunger,
      happiness: 100,
      mood: mood,
      lastUpdated: DateTime.now(),
      friendship: friendship + 2,
    );
    return next.copyWith(mood: next.currentMood.toLowerCase());
  }
}
