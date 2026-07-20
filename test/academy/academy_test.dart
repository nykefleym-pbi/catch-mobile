import 'package:catch_mobile/features/academy/data/academy_repository.dart';
import 'package:catch_mobile/features/academy/domain/care_lesson.dart';
import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('care lesson curriculum', () {
    test('lesson ids are unique', () {
      final ids = kCareLessons.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every lesson is well-formed and welfare-first', () {
      expect(kCareLessons, isNotEmpty);
      for (final l in kCareLessons) {
        expect(l.id, isNotEmpty);
        expect(l.title, isNotEmpty);
        expect(l.summary, isNotEmpty);
        expect(l.tips, isNotEmpty);
        final r = l.reflection;
        expect(r.options.length, greaterThanOrEqualTo(2), reason: l.id);
        expect(r.kindChoice, inInclusiveRange(0, r.options.length - 1),
            reason: l.id);
        expect(r.insight, isNotEmpty, reason: l.id);
      }
    });
  });

  group('progress helpers', () {
    test('completion requires every lesson id', () {
      final all = kCareLessons.map((l) => l.id).toSet();
      expect(academyIsComplete(all), isTrue);
      expect(academyIsComplete(const {}), isFalse);
      expect(academyCompletedCount(const {}), 0);
      expect(academyCompletedCount(all), kCareLessons.length);
    });

    test('unknown ids never count toward completion', () {
      expect(academyCompletedCount({'not_a_lesson'}), 0);
      expect(academyIsComplete({'not_a_lesson'}), isFalse);
    });
  });

  group('AcademyController persistence', () {
    Future<ProviderContainer> containerWith(Map<String, Object> seed) async {
      SharedPreferences.setMockInitialValues(seed);
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    }

    test('starts empty and marks a lesson complete, persisting it', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      expect(container.read(academyProgressProvider), isEmpty);
      expect(container.read(academyGraduateProvider), isFalse);

      final id = kCareLessons.first.id;
      await container.read(academyProgressProvider.notifier).markComplete(id);
      expect(container.read(academyProgressProvider), contains(id));
    });

    test('rehydrates prior progress and drops stale ids', () async {
      final good = kCareLessons.first.id;
      final container = await containerWith({
        'academy_completed_v1': [good, 'removed_lesson'],
      });
      addTearDown(container.dispose);

      final state = container.read(academyProgressProvider);
      expect(state, contains(good));
      expect(state, isNot(contains('removed_lesson'))); // pruned
    });

    test('graduate flag flips once every lesson is done', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      final notifier = container.read(academyProgressProvider.notifier);
      for (final l in kCareLessons) {
        await notifier.markComplete(l.id);
      }
      expect(container.read(academyGraduateProvider), isTrue);
    });
  });
}
