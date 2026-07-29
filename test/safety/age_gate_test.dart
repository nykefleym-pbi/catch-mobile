import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:catch_mobile/features/safety/data/age_gate.dart';
import 'package:catch_mobile/features/safety/domain/age_bracket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The age band is the regulatory keystone (ADR 0003 / ADR 0004). These tests
/// pin the two client guarantees that back the server-side enforcement in
/// migration 0013: the band rehydrates for synchronous gating, and the under-13
/// declaration is a one-way ratchet that cannot be relaxed to unlock social.
void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('AgeGateController', () {
    test('defaults to unknown (conservative) when nothing is stored', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      expect(container.read(ageBracketProvider), AgeBracket.unknown);
      // unknown gets the strictest posture: no social at all.
      final caps = container.read(socialCapabilitiesProvider);
      expect(caps.canUseSocial, isFalse);
      expect(caps.canAddFriends, isFalse);
      expect(caps.canTrade, isFalse);
    });

    test('records and rehydrates a chosen band', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      await container.read(ageBracketProvider.notifier).set(AgeBracket.adult);
      expect(container.read(ageBracketProvider), AgeBracket.adult);

      // A fresh container over the same prefs reads it back for sync gating.
      final prefs = await SharedPreferences.getInstance();
      final rebuilt = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(rebuilt.dispose);
      expect(rebuilt.read(ageBracketProvider), AgeBracket.adult);
    });

    test('under-13 is a one-way ratchet: cannot be relaxed to teen/adult',
        () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final notifier = container.read(ageBracketProvider.notifier);

      await notifier.set(AgeBracket.under13);
      expect(container.read(ageBracketProvider), AgeBracket.under13);

      // The bypass we are closing: re-declare adult to unlock social.
      await notifier.set(AgeBracket.adult);
      expect(container.read(ageBracketProvider), AgeBracket.under13,
          reason: 'under-13 must not be relaxed on the same install');

      await notifier.set(AgeBracket.teen);
      expect(container.read(ageBracketProvider), AgeBracket.under13);

      // And it stays under-13 across a rehydrate (prefs never got overwritten).
      final prefs = await SharedPreferences.getInstance();
      final rebuilt = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(rebuilt.dispose);
      expect(rebuilt.read(ageBracketProvider), AgeBracket.under13);
    });

    test('non-minor bands stay changeable (e.g. a teen turning 18)', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final notifier = container.read(ageBracketProvider.notifier);

      await notifier.set(AgeBracket.teen);
      expect(container.read(ageBracketProvider), AgeBracket.teen);
      // Teen may correct downward to under-13 (more conservative) ...
      await notifier.set(AgeBracket.under13);
      expect(container.read(ageBracketProvider), AgeBracket.under13);
    });

    test('a teen turning 18 can upgrade before any under-13 lock', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      final notifier = container.read(ageBracketProvider.notifier);

      await notifier.set(AgeBracket.teen);
      await notifier.set(AgeBracket.adult);
      expect(container.read(ageBracketProvider), AgeBracket.adult);
      final caps = container.read(socialCapabilitiesProvider);
      expect(caps.canUseSocial, isTrue);
    });
  });
}
