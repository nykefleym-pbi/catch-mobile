import 'package:catch_mobile/app.dart';
import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the Explore (map) destination once onboarded',
      (tester) async {
    // Treat this install as already onboarded so the router lands on the shell
    // rather than the first-launch welcome flow.
    SharedPreferences.setMockInitialValues({'onboarding_complete_v1': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CatchApp(),
      ),
    );
    // Bounded pumps rather than pumpAndSettle: the Explore map issues network
    // tile requests and a best-effort location lookup that never fully settle
    // in a test harness. The bottom-nav labels render on the first frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Explore'), findsWidgets);
    expect(find.text('CatDex'), findsOneWidget);
    expect(find.text('Guardian'), findsOneWidget);
  });

  testWidgets('first launch shows the welcome flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CatchApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text("Let's go meet some cats"), findsOneWidget);
  });
}
