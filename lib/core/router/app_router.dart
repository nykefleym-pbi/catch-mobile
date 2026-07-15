import 'package:go_router/go_router.dart';

import '../../features/capture/presentation/capture_screen.dart';
import '../../features/catdex/presentation/catdex_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// Central route table. Kept flat and simple for Phase 0; auth-gated redirects
/// and deep links come with the real auth flow in Phase 1.
class AppRoutes {
  const AppRoutes._();

  static const map = '/';
  static const catdex = '/catdex';
  static const capture = '/capture';
  static const profile = '/profile';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.map,
  routes: [
    // Full-screen capture flow, presented over the shell.
    GoRoute(
      path: AppRoutes.capture,
      builder: (context, state) => const CaptureScreen(),
    ),
    // Bottom-nav shell wrapping the primary destinations.
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.map,
          builder: (context, state) => const MapScreen(),
        ),
        GoRoute(
          path: AppRoutes.catdex,
          builder: (context, state) => const CatDexScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
