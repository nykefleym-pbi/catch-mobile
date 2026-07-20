import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/presentation/capture_screen.dart';
import '../../features/catdex/domain/cat.dart';
import '../../features/catdex/presentation/cat_detail_screen.dart';
import '../../features/catdex/presentation/catdex_screen.dart';
import '../../features/catdex/presentation/showcase_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/auth/presentation/account_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/seasonal/presentation/seasonal_screen.dart';
import '../../features/social/presentation/social_hub_screen.dart';

/// Central route table. Kept flat and simple; the only redirect is the
/// first-launch onboarding gate below.
class AppRoutes {
  const AppRoutes._();

  static const map = '/';
  static const catdex = '/catdex';
  static const capture = '/capture';
  static const profile = '/profile';
  static const catDetail = '/cat';
  static const onboarding = '/onboarding';
  static const account = '/account';
  static const social = '/social';
  static const seasonal = '/seasonal';
  static const showcase = '/showcase';

  /// Path for a single cat's detail page. Pass the [Cat] via `extra`.
  static String catDetailPath(String id) => '$catDetail/$id';
}

/// The app router, provided so it can react to the onboarding gate. Until the
/// welcome + consent flow is complete, every route redirects to `/onboarding`;
/// once complete, the guardian can no longer return to it.
final goRouterProvider = Provider<GoRouter>((ref) {
  // A tiny Listenable bridge so go_router re-evaluates `redirect` the moment
  // onboarding completes (ref.read inside redirect can't watch on its own).
  final refresh = ValueNotifier<bool>(ref.read(onboardingCompleteProvider));
  ref.onDispose(refresh.dispose);
  ref.listen<bool>(
    onboardingCompleteProvider,
    (_, next) => refresh.value = next,
  );

  return GoRouter(
    initialLocation: AppRoutes.map,
    refreshListenable: refresh,
    redirect: (context, state) {
      // The account screen is reachable at any time — a returning adult can
      // sign in straight from the welcome flow.
      if (state.matchedLocation == AppRoutes.account) return null;
      final onboarded = ref.read(onboardingCompleteProvider);
      final atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!onboarded) return atOnboarding ? null : AppRoutes.onboarding;
      if (atOnboarding) return AppRoutes.map;
      return null;
    },
    routes: [
      // First-launch welcome + consent flow.
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Cloud account (sign in / back up) for grown-ups. `extra == true` opens
      // straight in create-account mode; otherwise it opens to sign-in.
      GoRoute(
        path: AppRoutes.account,
        builder: (context, state) => (state.extra == true)
            ? const AccountScreen.create()
            : const AccountScreen.signIn(),
      ),
      // Full-screen capture flow, presented over the shell.
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => const CaptureScreen(),
      ),
      // Social hub (Friends & play), pushed over the shell from Profile.
      GoRoute(
        path: AppRoutes.social,
        builder: (context, state) => const SocialHubScreen(),
      ),
      // "This season" — cozy seasonal theme + featured cosmetics, pushed over
      // the shell from the CatDex banner.
      GoRoute(
        path: AppRoutes.seasonal,
        builder: (context, state) => const SeasonalScreen(),
      ),
      // CatDex showcase — a celebratory, read-only board of the player's own
      // collection, pushed over the shell from the CatDex header.
      GoRoute(
        path: AppRoutes.showcase,
        builder: (context, state) => const ShowcaseScreen(),
      ),
      // A single cat's detail + care page, pushed over the shell. The Cat is
      // handed over via `extra` from the CatDex to avoid a refetch.
      GoRoute(
        path: '${AppRoutes.catDetail}/:id',
        builder: (context, state) => CatDetailScreen(
          catId: state.pathParameters['id']!,
          cat: state.extra as Cat?,
        ),
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
});
