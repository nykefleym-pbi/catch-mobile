import 'package:flutter/foundation.dart';

import 'trait_effects.dart';

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

  /// Total number of bond tiers (for a hearts-style display).
  static int get levelCount => _bondLevels.length;

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
    this.hygiene = 100,
    this.sleep = 100,
    this.play = 100,
    this.friendship = 0,
    this.traitId,
  });

  final String catId;

  /// The cat's personality trait id (from `cats.trait_id`), or null. Drives the
  /// gentle, welfare-preserving care modulation in [TraitCareEffects] — a trait
  /// can only ever make a cat's care kinder, never harsher.
  final String? traitId;

  /// Values as last written to the database (0–100). Use the `currentX` getters
  /// for display so the drift-since-[lastUpdated] shows.
  final int hunger;
  final int happiness;

  /// Restored by grooming.
  final int hygiene;

  /// Recovers on its own while you're away; nudged down a little by play.
  final int sleep;

  /// The wish for playtime, restored by playing.
  final int play;

  final String mood;
  final DateTime lastUpdated;

  /// The permanent bond score (from `cats.friendship_level`). Grows with care.
  final int friendship;

  // Needs drift ~N points/hour, floored at [_floor] so they never bottom out.
  static const int _floor = 30;

  /// The personality modulation for this cat (identity when trait-less).
  TraitCareEffects get _effects => TraitCareEffects.forTrait(traitId);

  int get currentHunger => _decayed(hunger, 3 * _effects.hungerDecayMult);
  int get currentHappiness =>
      _decayed(happiness, 3 * _effects.happinessDecayMult);
  int get currentHygiene => _decayed(hygiene, 2 * _effects.hygieneDecayMult);
  int get currentPlay => _decayed(play, 2 * _effects.playDecayMult);

  /// Sleep is the kind one: it *recovers* over time (cats nap while you're
  /// away), so returning after a break finds a well-rested friend.
  int get currentSleep => _regened(sleep, 4 * _effects.sleepRegenMult);

  double _hoursSince() =>
      DateTime.now().difference(lastUpdated).inMinutes / 60.0;

  int _decayed(int base, num perHour) {
    final hours = _hoursSince();
    if (hours <= 0) return base.clamp(0, 100);
    return (base - perHour * hours).round().clamp(_floor, 100);
  }

  int _regened(int base, num perHour) {
    final hours = _hoursSince();
    if (hours <= 0) return base.clamp(0, 100);
    return (base + perHour * hours).round().clamp(0, 100);
  }

  /// A friendly mood label derived from the *current* needs that ask for
  /// attention (sleep self-recovers, so it doesn't drag the mood down).
  String get currentMood {
    final avg =
        (currentHunger + currentHappiness + currentHygiene + currentPlay) / 4;
    if (avg >= 85) return 'Blissful';
    if (avg >= 65) return 'Content';
    if (avg >= 45) return 'Restless';
    return 'Needy';
  }

  /// The single need most wanting attention right now, or null when everything
  /// is comfortably above [threshold]. Sleep is excluded on purpose — it
  /// self-recovers while you're away, so it should never drive a reminder (this
  /// mirrors [currentMood], which also ignores sleep). Ties resolve in a stable
  /// order. Used by the gentle while-away reminders so the copy can name the
  /// actual need ("a little snack", "in the mood to play") instead of a generic
  /// nudge — never nags when the cat is content (returns null).
  String? lowestNeed({int threshold = 45}) {
    final needs = <String, int>{
      'hunger': currentHunger,
      'happiness': currentHappiness,
      'hygiene': currentHygiene,
      'play': currentPlay,
    };
    String? lowestKey;
    var lowestValue = threshold;
    needs.forEach((key, value) {
      if (value < lowestValue) {
        lowestValue = value;
        lowestKey = key;
      }
    });
    return lowestKey;
  }

  /// A gentle "last cared for" label for the header.
  String get lastCaredLabel {
    final d = DateTime.now().difference(lastUpdated);
    if (d.inMinutes < 2) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) {
      return d.inHours == 1 ? 'an hour ago' : '${d.inHours} hours ago';
    }
    final days = d.inDays;
    return days == 1 ? 'yesterday' : '$days days ago';
  }

  String get bondLabel => Bond.labelFor(friendship);
  double get bondProgress => Bond.progressFor(friendship);
  bool get bondIsMax => Bond.isMax(friendship);

  /// A brand-new cat starts perfectly content (the row is created at capture).
  factory CareState.initial(String catId,
          {int friendship = 0, String? traitId}) =>
      CareState(
        catId: catId,
        hunger: 100,
        happiness: 100,
        hygiene: 100,
        sleep: 100,
        play: 100,
        mood: 'content',
        lastUpdated: DateTime.now(),
        friendship: friendship,
        traitId: traitId,
      );

  factory CareState.fromMap(Map<String, dynamic> map,
          {int friendship = 0, String? traitId}) =>
      CareState(
        catId: map['cat_id'] as String,
        hunger: (map['hunger'] as num?)?.toInt() ?? 100,
        happiness: (map['happiness'] as num?)?.toInt() ?? 100,
        hygiene: (map['hygiene'] as num?)?.toInt() ?? 100,
        sleep: (map['sleep'] as num?)?.toInt() ?? 100,
        play: (map['play'] as num?)?.toInt() ?? 100,
        mood: (map['mood'] as String?)?.trim().isNotEmpty == true
            ? map['mood'] as String
            : 'content',
        lastUpdated:
            DateTime.tryParse(map['last_updated'] as String? ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
        friendship: friendship,
        traitId: traitId,
      );

  /// The `care_state` row payload for an upsert (friendship lives on `cats` and
  /// is persisted separately). [profileId] is required by RLS on insert.
  Map<String, dynamic> toRow(String? profileId) => {
        'cat_id': catId,
        if (profileId != null) 'profile_id': profileId,
        'hunger': hunger,
        'happiness': happiness,
        'hygiene': hygiene,
        'sleep': sleep,
        'play': play,
        'mood': mood,
        'last_updated': lastUpdated.toUtc().toIso8601String(),
      };

  CareState copyWith({
    int? hunger,
    int? happiness,
    int? hygiene,
    int? sleep,
    int? play,
    String? mood,
    DateTime? lastUpdated,
    int? friendship,
    String? traitId,
  }) =>
      CareState(
        catId: catId,
        hunger: hunger ?? this.hunger,
        happiness: happiness ?? this.happiness,
        hygiene: hygiene ?? this.hygiene,
        sleep: sleep ?? this.sleep,
        play: play ?? this.play,
        mood: mood ?? this.mood,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        friendship: friendship ?? this.friendship,
        traitId: traitId ?? this.traitId,
      );

  /// A fresh snapshot at [DateTime.now], carrying every need forward at its
  /// *current* (drifted) value unless overridden — so an action only changes
  /// what it should, and the clock resets fairly no matter how long it's been.
  CareState _snapshot({
    int? hunger,
    int? happiness,
    int? hygiene,
    int? sleep,
    int? play,
    int? friendship,
  }) {
    final next = CareState(
      catId: catId,
      hunger: hunger ?? currentHunger,
      happiness: happiness ?? currentHappiness,
      hygiene: hygiene ?? currentHygiene,
      sleep: sleep ?? currentSleep,
      play: play ?? currentPlay,
      mood: mood,
      lastUpdated: DateTime.now(),
      friendship: friendship ?? this.friendship,
      traitId: traitId,
    );
    return next.copyWith(mood: next.currentMood.toLowerCase());
  }

  /// Feeding fills hunger, lifts spirits, and deepens the bond. The gains depend
  /// on the treat chosen ([bondGain] / [happinessGain]); a plain feed defaults
  /// to +1 bond. A food-loving personality gets a little extra (never less).
  CareState fed({int bondGain = 1, int happinessGain = 5}) => _snapshot(
        hunger: 100,
        happiness:
            (currentHappiness + happinessGain + _effects.feedHappinessBonus)
                .clamp(0, 100),
        friendship: friendship + bondGain + _effects.feedBondBonus,
      );

  /// Playing tops up the play + happiness needs, tires the cat out a touch
  /// (sleep), and bonds a little more than feeding (+2, more for a playful one).
  CareState played() => _snapshot(
        play: 100,
        happiness: 100,
        sleep: (currentSleep - 10).clamp(_floor, 100),
        friendship: friendship + 2 + _effects.playBondBonus,
      );

  /// Grooming freshens up hygiene, adds a little happiness, and bonds (+1);
  /// a shy cat is soothed a bit more by the gentle attention.
  CareState groomed() => _snapshot(
        hygiene: 100,
        happiness: (currentHappiness + 4 + _effects.groomHappinessBonus)
            .clamp(0, 100),
        friendship: friendship + 1 + _effects.groomBondBonus,
      );
}
