import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:catch_mobile/features/tutorial/data/tutorial_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tips start unseen; markSeen persists + is idempotent; resetAll clears',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(tutorialSeenProvider), isEmpty);

    await container.read(tutorialSeenProvider.notifier).markSeen('catdex');
    expect(container.read(tutorialSeenProvider).contains('catdex'), isTrue);
    expect(prefs.getStringList('tutorial_seen_v1'), contains('catdex'));

    // Idempotent — re-marking doesn't duplicate.
    await container.read(tutorialSeenProvider.notifier).markSeen('catdex');
    expect(container.read(tutorialSeenProvider).length, 1);

    await container.read(tutorialSeenProvider.notifier).resetAll();
    expect(container.read(tutorialSeenProvider), isEmpty);
    expect(prefs.getStringList('tutorial_seen_v1'), isNull);
  });
}
