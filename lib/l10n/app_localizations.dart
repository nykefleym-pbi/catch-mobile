import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Hand-rolled localization scaffold (Tagalog-first) for Cat-ch.
///
/// Strings live in per-locale maps below and are read through typed getters, so
/// every screen sources copy from one place instead of hardcoding it. English is
/// the template/fallback; `fil` (Filipino/Tagalog) is the launch-market locale.
///
/// This is deliberately a small manual delegate rather than `flutter gen-l10n`:
/// the CI environment can't run Flutter to generate the `.arb` output, so a
/// hand-rolled table keeps `flutter analyze`/`test` green today. Migrating these
/// tables to `.arb` + `flutter gen-l10n` is the documented follow-up
/// (see docs/decisions/0005-launch-readiness-accessibility-localization.md); the
/// getter surface below is designed so that migration is mechanical.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// The locales Cat-ch ships copy for. Order is display order.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fil'),
  ];

  static bool isSupportedCode(String code) =>
      _strings.containsKey(code);

  String _t(String key) =>
      _strings[locale.languageCode]?[key] ?? _strings['en']![key] ?? key;

  // --- Settings / language ---------------------------------------------------
  String get settingsTitle => _t('settingsTitle');
  String get settingsLanguageSection => _t('settingsLanguageSection');
  String get languageSystemDefault => _t('languageSystemDefault');
  String get languageEnglish => _t('languageEnglish');
  String get languageTagalog => _t('languageTagalog');
  String get settingsLanguageNote => _t('settingsLanguageNote');
  String get profileLanguageRowTitle => _t('profileLanguageRowTitle');
  String get profileLanguageRowSubtitle => _t('profileLanguageRowSubtitle');

  /// The per-locale string tables. `en` is the template; keep every locale's
  /// key set identical (a test enforces this).
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'settingsTitle': 'Settings',
      'settingsLanguageSection': 'Language',
      'languageSystemDefault': 'System default',
      'languageEnglish': 'English',
      'languageTagalog': 'Tagalog',
      'settingsLanguageNote':
          'Choose the language Cat-ch uses. This stays on your device.',
      'profileLanguageRowTitle': 'Language',
      'profileLanguageRowSubtitle': 'English & Tagalog',
    },
    'fil': {
      'settingsTitle': 'Mga Setting',
      'settingsLanguageSection': 'Wika',
      'languageSystemDefault': 'Default ng system',
      'languageEnglish': 'Ingles',
      'languageTagalog': 'Tagalog',
      'settingsLanguageNote':
          'Piliin ang wikang gagamitin ng Cat-ch. Nananatili ito sa iyong device.',
      'profileLanguageRowTitle': 'Wika',
      'profileLanguageRowSubtitle': 'Ingles at Tagalog',
    },
  };

  /// Exposed for the key-parity test only.
  @visibleForTesting
  static Map<String, Map<String, String>> get debugStrings => _strings;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.isSupportedCode(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
