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

/// Pure, testable policy that turns care snapshots into **gentle** local
/// reminders. Deliberately takes no clock/urgency input: the phrasing is always
/// calm and invitational (never "now", "hurry", "last chance"). Returns nothing
/// when notifications are disabled, for minors (structural minor-off), or when
/// no cat needs anything — so it can never nag.
List<GentleReminder> buildGentleReminders({
  required bool enabled,
  required bool isMinor,
  required List<CatNeedSnapshot> cats,
  int maxReminders = 2,
}) {
  if (!enabled || isMinor || maxReminders <= 0) return const [];
  final out = <GentleReminder>[];
  for (final cat in cats) {
    final need = cat.lowNeed;
    if (need == null) continue;
    final body = _bodyFor(cat.catName, need);
    if (body == null) continue;
    out.add(GentleReminder(catName: cat.catName, needKey: need, body: body));
    if (out.length >= maxReminders) break;
  }
  return out;
}

/// Calm, invitational copy per need. No urgency vocabulary by construction.
String? _bodyFor(String name, String need) {
  switch (need) {
    case 'hunger':
      return '$name would love a little snack whenever you have a moment.';
    case 'play':
      return '$name is in the mood to play when you are.';
    case 'happiness':
      return '$name would enjoy a little company sometime today.';
    case 'hygiene':
      return '$name could use a gentle spa day when it suits you.';
    case 'sleep':
      return '$name is finding a cozy spot to rest.';
    default:
      return null;
  }
}
