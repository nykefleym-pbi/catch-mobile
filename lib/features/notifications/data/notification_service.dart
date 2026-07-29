import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_policy.dart';

/// Thin wrapper over the local-notifications plugin for gentle, opt-in care
/// reminders. Local only — no FCM, no token, no server. The channel importance
/// is deliberately low so nudges are calm, never intrusive.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channelId = 'gentle_care';
  bool _inited = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Gentle care reminders',
      channelDescription: 'Calm, occasional nudges to care for your cats.',
      importance: Importance.low,
      priority: Priority.low,
    ),
  );

  // Every method is best-effort: a reminder must never crash the app, and this
  // also keeps the code safe under widget tests (no platform channel present).

  Future<void> init() async {
    if (_inited) return;
    try {
      tz_data.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      _inited = true;
    } catch (_) {
      // Leave uninitialised; the next call retries. Never surfaces to the user.
    }
  }

  /// Asks for the OS notifications permission (Android 13+). Returns whether it
  /// was granted; older Androids that don't gate this return true.
  Future<bool> requestPermission() async {
    await init();
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Shows the given gentle reminders as low-importance notifications now.
  Future<void> showReminders(List<GentleReminder> reminders) async {
    if (reminders.isEmpty) return;
    await init();
    try {
      var id = 100;
      for (final r in reminders) {
        await _plugin.show(id++, 'Cat-ch', r.body, _details);
      }
    } catch (_) {
      // best-effort
    }
  }

  /// Schedules gentle while-away reminders at calm future times (one per day),
  /// replacing any already scheduled. Uses inexact scheduling so it needs no
  /// exact-alarm permission and stays battery-friendly. All on-device.
  ///
  /// The reminder instant is computed from the desired local wall-clock time
  /// converted to UTC, so it fires at the right local time without needing the
  /// device's IANA timezone name.
  Future<void> scheduleGentleReminders(List<GentleReminder> reminders) async {
    await init();
    await cancelAll();
    if (reminders.isEmpty) return;
    try {
      final times = nextReminderTimes(DateTime.now(), reminders.length);
      var id = 200;
      for (var i = 0; i < reminders.length; i++) {
        final when = tz.TZDateTime.from(times[i].toUtc(), tz.UTC);
        await _plugin.zonedSchedule(
          id++,
          'Cat-ch',
          reminders[i].body,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // best-effort
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // best-effort
    }
  }
}

final flutterLocalNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>(
        (ref) => FlutterLocalNotificationsPlugin());

final notificationServiceProvider = Provider<NotificationService>(
    (ref) => NotificationService(ref.read(flutterLocalNotificationsProvider)));
