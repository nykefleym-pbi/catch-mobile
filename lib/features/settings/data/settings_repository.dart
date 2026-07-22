import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../onboarding/data/onboarding_repository.dart'
    show sharedPreferencesProvider;

/// K1 — app-preferences substrate (locale slice).
///
/// The player's chosen UI locale, or `null` to follow the device/system locale.
/// Persisted on-device via [SharedPreferences] (mirroring the onboarding flag
/// pattern) and never sent to the server — a locale is a device preference, and
/// keeping it local honours the data-minimisation posture (ADR 0003).
class LocaleController extends Notifier<Locale?> {
  static const _key = 'app_locale_v1';

  @override
  Locale? build() {
    final code = ref.read(sharedPreferencesProvider).getString(_key);
    if (code == null) return null;
    // Ignore a stored code we no longer ship, so a dropped locale falls back to
    // the system default instead of an unsupported one.
    return AppLocalizations.isSupportedCode(code) ? Locale(code) : null;
  }

  /// Sets the UI locale, or clears it (follow system) when [locale] is null.
  Future<void> setLocale(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = locale;
  }
}

/// The active UI locale override (`null` = follow system). Consumed by
/// `MaterialApp.router`'s `locale`, and by the Settings language picker.
final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
