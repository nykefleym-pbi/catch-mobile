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

  // --- Tutorial tips ---------------------------------------------------------
  String get settingsTipsSection => _t('settingsTipsSection');
  String get resetTips => _t('resetTips');
  String get resetTipsDone => _t('resetTipsDone');
  String get tipCatdex => _t('tipCatdex');
  String get tipMap => _t('tipMap');

  // --- Notifications ---------------------------------------------------------
  String get settingsNotificationsSection => _t('settingsNotificationsSection');
  String get notificationsToggle => _t('notificationsToggle');
  String get notificationsSubtitle => _t('notificationsSubtitle');
  String get notificationsConfirmBody => _t('notificationsConfirmBody');
  String get reminderVisitA => _t('reminderVisitA');
  String get reminderVisitB => _t('reminderVisitB');

  // Per-need reminder templates. `{name}` is replaced with the cat's name; the
  // notifications layer builds a ReminderStrings from these so the while-away
  // nudge can name the actual need. Copy stays calm — never urgency wording.
  String get reminderNeedHunger => _t('reminderNeedHunger');
  String get reminderNeedPlay => _t('reminderNeedPlay');
  String get reminderNeedHappiness => _t('reminderNeedHappiness');
  String get reminderNeedHygiene => _t('reminderNeedHygiene');
  String get reminderNeedSleep => _t('reminderNeedSleep');

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
      'settingsTipsSection': 'Tips',
      'resetTips': 'Show tips again',
      'resetTipsDone': 'Tips will show again.',
      'tipCatdex':
          'Long-press a cat to add your own private tags. Tap to open its page.',
      'tipMap': 'Cats you meet get pinned here. Tap a pin to visit that friend.',
      'settingsNotificationsSection': 'Notifications',
      'notificationsToggle': 'Gentle care reminders',
      'notificationsSubtitle':
          'Occasional, calm nudges to care for your cats. Off by default.',
      'notificationsConfirmBody':
          'You\'ll get the occasional gentle nudge to care for your cats.',
      'reminderVisitA':
          'Your cats would love a little visit when you have a moment.',
      'reminderVisitB':
          'A cozy spot is waiting — come check in on your cats sometime.',
      'reminderNeedHunger':
          '{name} would love a little snack whenever you have a moment.',
      'reminderNeedPlay': '{name} is in the mood to play when you are.',
      'reminderNeedHappiness':
          '{name} would enjoy a little company sometime today.',
      'reminderNeedHygiene':
          '{name} could use a gentle spa day when it suits you.',
      'reminderNeedSleep': '{name} is finding a cozy spot to rest.',
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
      'settingsTipsSection': 'Mga Tip',
      'resetTips': 'Ipakita muli ang mga tip',
      'resetTipsDone': 'Muling lalabas ang mga tip.',
      'tipCatdex':
          'Pindutin nang matagal ang isang pusa para maglagay ng sarili mong '
              'pribadong tag. I-tap para buksan ang pahina nito.',
      'tipMap': 'Ang mga pusang nakikilala mo ay nakalagay dito. I-tap ang pin '
          'para bisitahin ang kaibigang iyon.',
      'settingsNotificationsSection': 'Mga Abiso',
      'notificationsToggle': 'Banayad na paalala sa pag-aalaga',
      'notificationsSubtitle': 'Paminsan-minsang banayad na paalala para '
          'alagaan ang iyong mga pusa. Naka-off bilang default.',
      'notificationsConfirmBody': 'Makakatanggap ka ng paminsan-minsang banayad '
          'na paalala para alagaan ang iyong mga pusa.',
      'reminderVisitA': 'Gustong-gusto ng iyong mga pusa na dalawin mo sila '
          'kapag may oras ka.',
      'reminderVisitB': 'May maaliwalas na tulugan na naghihintay — dalawin ang '
          'iyong mga pusa kapag nagkaroon ng pagkakataon.',
      'reminderNeedHunger': 'Gustong-gusto ni {name} ng kaunting meryenda kapag '
          'may oras ka.',
      'reminderNeedPlay': 'Gustong maglaro ni {name} kapag handa ka na.',
      'reminderNeedHappiness':
          'Ikatutuwa ni {name} ang kaunting kasama sa araw na ito.',
      'reminderNeedHygiene': 'Kakailanganin ni {name} ng banayad na spa day '
          'kapag nababagay sa iyo.',
      'reminderNeedSleep': 'Naghahanap si {name} ng maaliwalas na tulugan.',
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
