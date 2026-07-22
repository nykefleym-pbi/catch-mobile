import 'care_lesson.dart';

/// Weaves the Care Academy into everyday care: given the current needs, returns
/// the welfare lesson that speaks to whatever needs attention right now — so a
/// lesson surfaces *at the moment it matters* rather than as a separate chore.
///
/// Pure and testable. Returns `null` when nothing is low enough to bother the
/// player, so it never nags. When several needs are low, the lowest wins (ties
/// broken by the fixed priority order below).
String? lessonForCareMoment({
  required int hunger,
  required int happiness,
  required int hygiene,
  required int sleep,
  required int play,
  int threshold = 35,
}) {
  // Order is the tie-break priority; each maps a low need to the lesson that
  // teaches how to meet it. Every id exists in [kCareLessons].
  final candidates = <({int value, String lesson})>[
    (value: hunger, lesson: 'water'),
    (value: play, lesson: 'enrichment'),
    (value: sleep, lesson: 'safe_home'),
    (value: happiness, lesson: 'gentle_handling'),
    (value: hygiene, lesson: 'vet'),
  ];

  ({int value, String lesson})? lowest;
  for (final c in candidates) {
    if (c.value < threshold && (lowest == null || c.value < lowest.value)) {
      lowest = c;
    }
  }
  return lowest?.lesson;
}

/// Looks up the [CareLesson] for an id, or null if it isn't in the curriculum.
CareLesson? careLessonById(String id) {
  for (final lesson in kCareLessons) {
    if (lesson.id == id) return lesson;
  }
  return null;
}
