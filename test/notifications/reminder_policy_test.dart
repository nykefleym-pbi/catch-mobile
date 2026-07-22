import 'package:catch_mobile/features/notifications/domain/reminder_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cats = [
    CatNeedSnapshot(catName: 'Milo', lowNeed: 'hunger'),
    CatNeedSnapshot(catName: 'Luna', lowNeed: 'play'),
    CatNeedSnapshot(catName: 'Sol', lowNeed: 'hygiene'),
  ];

  test('disabled → no reminders', () {
    expect(
      buildGentleReminders(enabled: false, isMinor: false, cats: cats),
      isEmpty,
    );
  });

  test('minors never get reminders, even when enabled', () {
    expect(
      buildGentleReminders(enabled: true, isMinor: true, cats: cats),
      isEmpty,
    );
  });

  test('healthy cats produce nothing (never nags)', () {
    expect(
      buildGentleReminders(
        enabled: true,
        isMinor: false,
        cats: const [CatNeedSnapshot(catName: 'Milo', lowNeed: null)],
      ),
      isEmpty,
    );
  });

  test('respects the frequency cap', () {
    final out = buildGentleReminders(
        enabled: true, isMinor: false, cats: cats, maxReminders: 2);
    expect(out.length, 2);
  });

  test('copy is gentle — never urgency/streak/FOMO wording', () {
    final out =
        buildGentleReminders(enabled: true, isMinor: false, cats: cats, maxReminders: 3);
    expect(out, isNotEmpty);
    const banned = [
      'now',
      'hurry',
      'urgent',
      'last chance',
      "don't miss",
      'streak',
      'expire',
      'limited',
      'quick',
      '!'
    ];
    for (final r in out) {
      final body = r.body.toLowerCase();
      for (final word in banned) {
        expect(body.contains(word), isFalse,
            reason: 'reminder "${r.body}" must not use urgency wording "$word"');
      }
    }
  });

  group('nextReminderTimes (while-away scheduling)', () {
    test('before the hour: first is today at the hour, then daily', () {
      final now = DateTime(2026, 7, 22, 10);
      final times = nextReminderTimes(now, 2);
      expect(times, [DateTime(2026, 7, 22, 18), DateTime(2026, 7, 23, 18)]);
      expect(times.every((t) => t.isAfter(now)), isTrue);
    });

    test('past the hour: first rolls to tomorrow', () {
      final now = DateTime(2026, 7, 22, 20);
      final times = nextReminderTimes(now, 1);
      expect(times, [DateTime(2026, 7, 23, 18)]);
    });

    test('count 0 yields no times', () {
      expect(nextReminderTimes(DateTime.now(), 0), isEmpty);
    });
  });
}
