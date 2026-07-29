/// The launch-market geo-gate for **live** social.
///
/// It is a second lock in series with [kSocialLive] (see `safe_play.dart`): even
/// once the master switch is on, live user-to-user surfaces open only in markets
/// whose store privacy declarations and legal review have cleared (pre-launch
/// dossier §5.4 "store privacy declarations + geo-gating", §7.4). Keeping the
/// "which markets" decision a *config* choice — the `LAUNCH_MARKETS` dart-define
/// (`Env.launchMarkets`) — means opening or closing a market later is a build
/// flag, not a code patch.
///
/// This is a pure, testable rule with no Flutter/Riverpod dependency so it can be
/// exercised directly in `test/social/social_launch_gate_test.dart`. The runtime
/// wiring (device region + effective provider) lives in
/// `data/social_live_provider.dart`.
class SocialLaunchGate {
  const SocialLaunchGate._();

  /// Whether live social should be active for a player physically in [region]
  /// (an ISO 3166-1 alpha-2 code, or `null` when unknown).
  ///
  /// Evaluated in order:
  /// 1. **Master switch off** ⇒ never live. `kSocialLive` wins over everything;
  ///    this is the compile-time backstop the repos also gate on.
  /// 2. **No allowlist configured** ⇒ unrestricted. An empty [launchMarkets] is
  ///    the dev / single-region default — set `LAUNCH_MARKETS` to restrict.
  /// 3. **Allowlist present** ⇒ live only when [region] is a cleared market. An
  ///    unknown region (`null`) **fails closed**: we never enable live social
  ///    for a device we cannot place inside a cleared market.
  static bool isLive({
    required bool socialLive,
    required Set<String> launchMarkets,
    required String? region,
  }) {
    if (!socialLive) return false;
    if (launchMarkets.isEmpty) return true;
    if (region == null || region.isEmpty) return false;
    return launchMarkets.contains(region.toUpperCase());
  }
}
