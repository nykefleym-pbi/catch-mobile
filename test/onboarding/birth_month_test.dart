import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The birthday month is an optional, minimized signal (month only — never a
/// full birth date) captured during onboarding so the app can celebrate a
/// player's special month. These tests pin the two guarantees the client relies
/// on: it persists/rehydrates, and it never stores a nonsense value.
void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('BirthMonthController', () {
    test('defaults to null when nothing is stored', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      expect(container.read(birthMonthProvider), isNull);
    });

    test('records and rehydrates a chosen month', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      await container.read(birthMonthProvider.notifier).set(7);
      expect(container.read(birthMonthProvider), 7);

      // A fresh container over the same prefs reads it back.
      final prefs = await SharedPreferences.getInstance();
      final rebuilt = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(rebuilt.dispose);
      expect(rebuilt.read(birthMonthProvider), 7);
    });

    test('ignores out-of-range months (guards against bad input)', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final notifier = container.read(birthMonthProvider.notifier);

      await notifier.set(0);
      expect(container.read(birthMonthProvider), isNull);
      await notifier.set(13);
      expect(container.read(birthMonthProvider), isNull);

      await notifier.set(12);
      expect(container.read(birthMonthProvider), 12);
    });

    test('a stored out-of-range value rehydrates as null', () async {
      final container = await containerWith({'birth_month_v1': 99});
      addTearDown(container.dispose);
      expect(container.read(birthMonthProvider), isNull);
    });
  });
}
