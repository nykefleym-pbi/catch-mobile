import 'package:catch_mobile/features/notifications/data/notification_prefs.dart';
import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:catch_mobile/features/safety/data/age_gate.dart';
import 'package:catch_mobile/features/safety/domain/age_bracket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MinorGate extends AgeGateController {
  @override
  AgeBracket build() => AgeBracket.under13;
}

class _AdultGate extends AgeGateController {
  @override
  AgeBracket build() => AgeBracket.adult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('off by default; an adult can enable and it persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ageBracketProvider.overrideWith(_AdultGate.new),
    ]);
    addTearDown(container.dispose);

    expect(container.read(notificationsEnabledProvider), isFalse);
    await container.read(notificationsEnabledProvider.notifier).setEnabled(true);
    expect(container.read(notificationsEnabledProvider), isTrue);
    expect(prefs.getBool('notifications_enabled_v1'), isTrue);
  });

  test('minors are always off and can never enable', () async {
    // Even with a stored `true`, a minor bracket forces it off.
    SharedPreferences.setMockInitialValues(
        {'notifications_enabled_v1': true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ageBracketProvider.overrideWith(_MinorGate.new),
    ]);
    addTearDown(container.dispose);

    expect(container.read(notificationsEnabledProvider), isFalse);
    await container.read(notificationsEnabledProvider.notifier).setEnabled(true);
    expect(container.read(notificationsEnabledProvider), isFalse); // no-op
  });
}
