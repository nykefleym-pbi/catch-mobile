import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/onboarding_repository.dart'
    show sharedPreferencesProvider;

/// Tracks which screens have shown their first-run tip. On-device only (no
/// server, no data collected) so it's safe under the reduced-data minor mode.
/// Versioned key so a future tutorial refresh can re-show tips cleanly.
const _seenKey = 'tutorial_seen_v1';

class TutorialController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final stored = ref.read(sharedPreferencesProvider).getStringList(_seenKey);
    return {...?stored};
  }

  /// Marks a screen's tip as seen. Idempotent — re-marking is a no-op.
  Future<void> markSeen(String screenId) async {
    if (state.contains(screenId)) return;
    final next = {...state, screenId};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_seenKey, next.toList());
    state = next;
  }

  /// Clears all tips so they show again (wired to Settings → "Show tips again").
  Future<void> resetAll() async {
    await ref.read(sharedPreferencesProvider).remove(_seenKey);
    state = {};
  }
}

/// The set of screen ids whose first-run tip has been dismissed.
final tutorialSeenProvider =
    NotifierProvider<TutorialController, Set<String>>(TutorialController.new);
