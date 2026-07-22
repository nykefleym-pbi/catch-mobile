import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:catch_mobile/features/settings/presentation/settings_screen.dart';
import 'package:catch_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the text-scaling / reachability work (item 6): a screen must reflow
/// without overflowing when the OS text size is cranked up. New screens can be
/// added to this harness as they're built.
Future<void> _pumpAtScale(
  WidgetTester tester,
  Widget screen,
  double scale,
  SharedPreferences prefs,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings reflows without overflow at 1.0x and 2.0x text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    for (final scale in [1.0, 2.0]) {
      await _pumpAtScale(tester, const SettingsScreen(), scale, prefs);
      expect(tester.takeException(), isNull,
          reason: 'Settings overflowed at ${scale}x text scale');
    }
  });
}
