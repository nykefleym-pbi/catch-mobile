import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../notifications/data/notification_prefs.dart';
import '../../notifications/data/notification_service.dart';
import '../../notifications/domain/reminder_policy.dart';
import '../../safety/data/age_gate.dart';
import '../../tutorial/data/tutorial_repository.dart';
import '../data/settings_repository.dart';

/// App Settings — the K1 preferences surface. For Slice A it hosts the language
/// picker; later launch-readiness prefs (notifications, reachability) slot in
/// here as new sections.
///
/// This screen is the localization "proof" surface: every visible string is
/// sourced from [AppLocalizations], not hardcoded.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentCode = ref.watch(localeProvider)?.languageCode; // null = system

    void choose(Locale? locale) =>
        ref.read(localeProvider.notifier).setLocale(locale);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Text(
                l.settingsLanguageSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _LanguageOption(
              label: l.languageSystemDefault,
              selected: currentCode == null,
              onTap: () => choose(null),
            ),
            _LanguageOption(
              label: l.languageEnglish,
              selected: currentCode == 'en',
              onTap: () => choose(const Locale('en')),
            ),
            _LanguageOption(
              label: l.languageTagalog,
              selected: currentCode == 'fil',
              onTap: () => choose(const Locale('fil')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Text(
                l.settingsLanguageNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(
                l.settingsTipsSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(l.resetTips),
              onTap: () async {
                await ref.read(tutorialSeenProvider.notifier).resetAll();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.resetTipsDone)),
                );
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(
                l.settingsNotificationsSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Opt-in, off by default; disabled entirely for minors (they can
            // never enable — enforced in the provider too).
            SwitchListTile(
              value: ref.watch(notificationsEnabledProvider),
              title: Text(l.notificationsToggle),
              subtitle: Text(l.notificationsSubtitle),
              onChanged: ref.watch(ageBracketProvider).isMinor
                  ? null
                  : (enabled) async {
                      final notifier =
                          ref.read(notificationsEnabledProvider.notifier);
                      final service = ref.read(notificationServiceProvider);
                      if (enabled) {
                        final granted = await service.requestPermission();
                        if (!granted) return;
                        await notifier.setEnabled(true);
                        await service.showReminders([
                          GentleReminder(
                            catName: '',
                            needKey: '',
                            body: l.notificationsConfirmBody,
                          ),
                        ]);
                      } else {
                        await notifier.setEnabled(false);
                        await service.cancelAll();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// A single selectable language row — a check marks the active choice. Avoids
/// RadioListTile's deprecated group API.
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      selected: selected,
    );
  }
}
