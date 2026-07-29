/// A single gentle care reminder — no urgency, no streaks, no FOMO.
class GentleReminder {
  const GentleReminder({required this.catName, required this.needKey, required this.body});

  final String catName;
  final String needKey;
  final String body;
}

/// A minimal snapshot of a cat's care state for reminder purposes: the cat's
/// name and its single lowest need (or null when everything is healthy).
class CatNeedSnapshot {
  const CatNeedSnapshot({required this.catName, required this.lowNeed});

  final String catName;

  /// One of 'hunger' | 'happiness' | 'hygiene' | 'sleep' | 'play', or null.
  final String? lowNeed;
}

/// The calm, per-need reminder copy, kept separate from the policy so it can be
/// **localized**: the presentation layer builds one of these from the active
/// [AppLocalizations] (en/fil), while the pure policy and its tests use the
/// English [ReminderStrings.english] default. Each template carries a `{name}`
/// placeholder for the cat's name. No urgency vocabulary by construction.
class ReminderStrings {
  const ReminderStrings({
    required this.hunger,
    required this.play,
    required this.happiness,
    required this.hygiene,
    required this.sleep,
  });

  final String hunger;
  final String play;
  final String happiness;
  final String hygiene;
  final String sleep;

  /// The localized body for [name]'s lowest [need], or null for an unknown need.
  String? bodyFor(String name, String need) {
    final template = switch (need) {
      'hunger' => hunger,
      'play' => play,
      'happiness' => happiness,
      'hygiene' => hygiene,
      'sleep' => sleep,
      _ => null,
    };
    return template?.replaceAll('{name}', name);
  }

  /// English template + fallback (also what the pure tests assert against).
  static const ReminderStrings english = ReminderStrings(
    hunger: '{name} would love a little snack whenever you have a moment.',
    play: '{name} is in the mood to play when you are.',
    happiness: '{name} would enjoy a little company sometime today.',
    hygiene: '{name} could use a gentle spa day when it suits you.',
    sleep: '{name} is finding a cozy spot to rest.',
  );
}

/// Pure, testable policy that turns care snapshots into **gentle** local
/// reminders. Deliberately takes no clock/urgency input: the phrasing is always
/// calm and invitational (never "now", "hurry", "last chance"). Returns nothing
/// when notifications are disabled, for minors (structural minor-off), or when
/// no cat needs anything — so it can never nag. Copy comes from [strings] so it
/// can be localized; defaults to English.
List<GentleReminder> buildGentleReminders({
  required bool enabled,
  required bool isMinor,
  required List<CatNeedSnapshot> cats,
  int maxReminders = 2,
  ReminderStrings strings = ReminderStrings.english,
}) {
  if (!enabled || isMinor || maxReminders <= 0) return const [];
  final out = <GentleReminder>[];
  for (final cat in cats) {
    final need = cat.lowNeed;
    if (need == null) continue;
    final body = strings.bodyFor(cat.catName, need);
    if (body == null) continue;
    out.add(GentleReminder(catName: cat.catName, needKey: need, body: body));
    if (out.length >= maxReminders) break;
  }
  return out;
}

/// Calm fire times for while-away reminders: the next occurrence of [hour]
/// (local wall-clock), then one per following day, up to [count]. Pure and
/// testable; the caller converts each to an absolute instant for scheduling.
/// Spacing them a day apart keeps reminders gentle, never a rapid drip.
List<DateTime> nextReminderTimes(DateTime now, int count, {int hour = 18}) {
  if (count <= 0) return const [];
  var first = DateTime(now.year, now.month, now.day, hour);
  if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
  return [for (var i = 0; i < count; i++) first.add(Duration(days: i))];
}
