import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../safety/data/age_gate.dart';
import '../data/notification_prefs.dart';
import '../data/notification_service.dart';
import '../domain/reminder_policy.dart';

/// Keeps the while-away care reminders in sync with the player's opt-in choice.
///
/// Wrapped around the app below the Localizations layer. On every app open and
/// background, it re-schedules (or clears) the reminders — so they stay fresh,
/// respect the frequency cap, and are removed the moment the player opts out or
/// is a minor. All on-device; scheduling is inexact (no exact-alarm permission).
class NotificationScheduler extends ConsumerStatefulWidget {
  const NotificationScheduler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationScheduler> createState() =>
      _NotificationSchedulerState();
}

class _NotificationSchedulerState extends ConsumerState<NotificationScheduler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_sync()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      unawaited(_sync());
    }
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final enabled = ref.read(notificationsEnabledProvider);
    final isMinor = ref.read(ageBracketProvider).isMinor;
    final service = ref.read(notificationServiceProvider);
    if (!enabled || isMinor) {
      await service.cancelAll();
      return;
    }
    // Read localized copy before any await (context stays valid here).
    final l = AppLocalizations.of(context);
    final reminders = [
      GentleReminder(catName: '', needKey: '', body: l.reminderVisitA),
      GentleReminder(catName: '', needKey: '', body: l.reminderVisitB),
    ];
    await service.scheduleGentleReminders(reminders);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
