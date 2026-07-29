import 'package:catch_mobile/features/academy/domain/care_lesson.dart';
import 'package:catch_mobile/features/academy/domain/care_moment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('healthy needs surface no lesson (never nags)', () {
    expect(
      lessonForCareMoment(
          hunger: 90, happiness: 90, hygiene: 90, sleep: 90, play: 90),
      isNull,
    );
  });

  test('a single low need maps to its lesson', () {
    expect(
      lessonForCareMoment(
          hunger: 20, happiness: 90, hygiene: 90, sleep: 90, play: 90),
      'water',
    );
    expect(
      lessonForCareMoment(
          hunger: 90, happiness: 90, hygiene: 90, sleep: 90, play: 10),
      'enrichment',
    );
  });

  test('the lowest need wins when several are low', () {
    // play (15) is lower than hunger (30) -> enrichment.
    expect(
      lessonForCareMoment(
          hunger: 30, happiness: 90, hygiene: 90, sleep: 90, play: 15),
      'enrichment',
    );
  });

  test('every mapped lesson id exists in the curriculum', () {
    for (final v in [0, 10, 20, 30]) {
      final id = lessonForCareMoment(
          hunger: v, happiness: v, hygiene: v, sleep: v, play: v);
      expect(id, isNotNull);
      expect(careLessonById(id!), isNotNull);
    }
    // sanity: careLessonById returns a real lesson
    expect(kCareLessons.map((l) => l.id), contains('water'));
  });
}
