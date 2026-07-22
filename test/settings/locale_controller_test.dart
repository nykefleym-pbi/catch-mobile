import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:catch_mobile/features/settings/data/settings_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('locale defaults to system (null), then persists and clears', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(localeProvider), isNull);

    await container.read(localeProvider.notifier).setLocale(const Locale('fil'));
    expect(container.read(localeProvider)?.languageCode, 'fil');
    expect(prefs.getString('app_locale_v1'), 'fil');

    await container.read(localeProvider.notifier).setLocale(null);
    expect(container.read(localeProvider), isNull);
    expect(prefs.getString('app_locale_v1'), isNull);
  });

  test('an unsupported stored code falls back to system (null)', () async {
    SharedPreferences.setMockInitialValues({'app_locale_v1': 'xx'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(localeProvider), isNull);
  });
}
