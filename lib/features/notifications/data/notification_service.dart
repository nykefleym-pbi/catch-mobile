import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reminder_policy.dart';

/// Thin wrapper over the local-notifications plugin for gentle, opt-in care
/// reminders. Local only — no FCM, no token, no server. The channel importance
/// is deliberately low so nudges are calm, never intrusive.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channelId = 'gentle_care';
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _inited = true;
  }

  /// Asks for the OS notifications permission (Android 13+). Returns whether it
  /// was granted; older Androids that don't gate this return true.
  Future<bool> requestPermission() async {
    await init();
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Shows up to the given gentle reminders as low-importance notifications.
  Future<void> showReminders(List<GentleReminder> reminders) async {
    if (reminders.isEmpty) return;
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Gentle care reminders',
        channelDescription: 'Calm, occasional nudges to care for your cats.',
        importance: Importance.low,
        priority: Priority.low,
      ),
    );
    var id = 100;
    for (final r in reminders) {
      await _plugin.show(id++, 'Cat-ch', r.body, details);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

final flutterLocalNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>(
        (ref) => FlutterLocalNotificationsPlugin());

final notificationServiceProvider = Provider<NotificationService>(
    (ref) => NotificationService(ref.read(flutterLocalNotificationsProvider)));
