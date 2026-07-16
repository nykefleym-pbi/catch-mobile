import 'package:flutter/foundation.dart';

/// A cat's care needs — hunger + happiness — mirroring the `care_state` row
/// (docs/architecture/06-data-model.md).
///
/// Decay is deliberately **gentle and non-punitive**: needs drift down slowly
/// since [lastUpdated] and are floored at [_floor] so a cat is never left
/// miserable. Care here is a warm little ritual, not a punishment loop — there
/// is no server cron; the client simply computes the decayed value on read and
/// writes a fresh snapshot whenever the player feeds or plays.
@immutable
class CareState {
  const CareState({
    required this.catId,
    required this.hunger,
    required this.happiness,
    required this.mood,
    required this.lastUpdated,
  });

  final String catId;

  /// Values as last written to the database (0–100). Use [currentHunger] /
  /// [currentHappiness] for display so the decay-since-[lastUpdated] shows.
  final int hunger;
  final int happiness;
  final String mood;
  final DateTime lastUpdated;

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

  /// A brand-new cat starts perfectly content (the row is created at capture).
  factory CareState.initial(String catId) => CareState(
        catId: catId,
        hunger: 100,
        happiness: 100,
        mood: 'content',
        lastUpdated: DateTime.now(),
      );

  factory CareState.fromMap(Map<String, dynamic> map) => CareState(
        catId: map['cat_id'] as String,
        hunger: (map['hunger'] as num?)?.toInt() ?? 100,
        happiness: (map['happiness'] as num?)?.toInt() ?? 100,
        mood: (map['mood'] as String?)?.trim().isNotEmpty == true
            ? map['mood'] as String
            : 'content',
        lastUpdated:
            DateTime.tryParse(map['last_updated'] as String? ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
      );

  /// The row payload for an upsert. [profileId] is required by RLS on insert;
  /// on update it simply matches the existing owner.
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
  }) =>
      CareState(
        catId: catId,
        hunger: hunger ?? this.hunger,
        happiness: happiness ?? this.happiness,
        mood: mood ?? this.mood,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  /// Feeding fills hunger and lifts spirits a little. Built from the *current*
  /// decayed values so it's fair no matter how long it's been.
  CareState fed() {
    final next = CareState(
      catId: catId,
      hunger: 100,
      happiness: (currentHappiness + 5).clamp(0, 100),
      mood: mood,
      lastUpdated: DateTime.now(),
    );
    return next.copyWith(mood: next.currentMood.toLowerCase());
  }

  /// Playing tops up happiness (a joyful moment together).
  CareState played() {
    final next = CareState(
      catId: catId,
      hunger: currentHunger,
      happiness: 100,
      mood: mood,
      lastUpdated: DateTime.now(),
    );
    return next.copyWith(mood: next.currentMood.toLowerCase());
  }
}
