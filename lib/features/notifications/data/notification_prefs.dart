import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/onboarding_repository.dart'
    show sharedPreferencesProvider;
import '../../safety/data/age_gate.dart';

/// Whether gentle local care reminders are enabled.
///
/// Off by default. **Minors can never enable them** — the getter returns false
/// for any minor bracket and [setEnabled] refuses to persist true for a minor,
/// so the minor-off guarantee is structural (ADR 0005), not just a default.
/// Everything is on-device; there is no push token or server involvement.
const _notifKey = 'notifications_enabled_v1';

class NotificationPrefsController extends Notifier<bool> {
  @override
  bool build() {
    // Recompute if the age band changes; minors are always off.
    if (ref.watch(ageBracketProvider).isMinor) return false;
    return ref.read(sharedPreferencesProvider).getBool(_notifKey) ?? false;
  }

  /// Enables/disables reminders. A no-op for minors (they can never opt in).
  Future<void> setEnabled(bool enabled) async {
    if (ref.read(ageBracketProvider).isMinor) return;
    await ref.read(sharedPreferencesProvider).setBool(_notifKey, enabled);
    state = enabled;
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationPrefsController, bool>(
        NotificationPrefsController.new);
