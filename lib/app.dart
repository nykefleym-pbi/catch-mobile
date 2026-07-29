import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/notification_scheduler.dart';
import 'features/settings/data/settings_repository.dart';
import 'l10n/app_localizations.dart';

/// Root widget. Themed, routed, localized, and ready for the feature modules to
/// fill in.
class CatchApp extends ConsumerWidget {
  const CatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null locale = follow the device/system locale; a Settings override wins.
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Cat-ch Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(goRouterProvider),
      // Below Localizations: keep while-away care reminders in sync with the
      // opt-in choice on every app open/background.
      builder: (context, child) => NotificationScheduler(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
