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

/// Persisted key for the player's birth month (1–12, or 0 = not shared).
///
/// We keep only the *month* — never a day or year — so it's enough to celebrate
/// someone's special month without collecting a full birth date (still honours
/// the data-minimization posture of the age gate). It's optional; a player can
/// skip it. Stored locally so the birthday-celebration feature can read it
/// without a round-trip.
const _birthMonthKey = 'birth_month_v1';

/// Holds the (optional) birth month chosen during onboarding. `null` means the
/// player hasn't shared one; otherwise 1 (January) … 12 (December).
class BirthMonthController extends Notifier<int?> {
  @override
  int? build() {
    final stored = ref.read(sharedPreferencesProvider).getInt(_birthMonthKey);
    return (stored != null && stored >= 1 && stored <= 12) ? stored : null;
  }

  /// Records the chosen month (1–12) and persists it.
  Future<void> set(int month) async {
    if (month < 1 || month > 12) return;
    await ref.read(sharedPreferencesProvider).setInt(_birthMonthKey, month);
    state = month;
  }
}

final birthMonthProvider =
    NotifierProvider<BirthMonthController, int?>(BirthMonthController.new);
