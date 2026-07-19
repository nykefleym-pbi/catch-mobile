import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the resolved [SharedPreferences]. It's overridden in `main()` (and
/// in tests) with the real instance so the router can decide first-launch
/// gating synchronously — reading it without that override is a programming
/// error, hence the deliberate throw.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Persisted flag key. Versioned so a future flow change can re-onboard users.
const _onboardingCompleteKey = 'onboarding_complete_v1';

/// Tracks whether the guardian has finished the welcome + consent flow. Exposed
/// as synchronous state so the router redirect can gate the very first launch;
/// the backing write goes to [SharedPreferences] so the choice survives
/// restarts.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_onboardingCompleteKey) ??
      false;

  /// Marks onboarding done and persists it. The router reacts to the state
  /// change and moves the guardian on to the map.
  Future<void> complete() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_onboardingCompleteKey, true);
    state = true;
  }
}

final onboardingCompleteProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
