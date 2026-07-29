import 'package:catch_mobile/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every locale defines exactly the English key set (no gaps)', () {
    final strings = AppLocalizations.debugStrings;
    final enKeys = strings['en']!.keys.toSet();
    for (final entry in strings.entries) {
      expect(
        entry.value.keys.toSet(),
        enKeys,
        reason: 'locale "${entry.key}" must define the same keys as English',
      );
      for (final value in entry.value.values) {
        expect(value.trim(), isNotEmpty,
            reason: 'locale "${entry.key}" has an empty string');
      }
    }
  });

  test('fil resolves Tagalog copy; en is the template', () {
    const fil = AppLocalizations(Locale('fil'));
    const en = AppLocalizations(Locale('en'));
    expect(fil.settingsTitle, 'Mga Setting');
    expect(en.settingsTitle, 'Settings');
    expect(fil.languageTagalog, 'Tagalog');
  });

  test('an unsupported locale falls back to the English string', () {
    const other = AppLocalizations(Locale('xx'));
    expect(other.settingsTitle, 'Settings');
  });

  test('supported locales + delegate', () {
    expect(AppLocalizations.isSupportedCode('fil'), isTrue);
    expect(AppLocalizations.isSupportedCode('xx'), isFalse);
    expect(AppLocalizations.delegate.isSupported(const Locale('fil')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('xx')), isFalse);
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      containsAll(<String>['en', 'fil']),
    );
  });
}
