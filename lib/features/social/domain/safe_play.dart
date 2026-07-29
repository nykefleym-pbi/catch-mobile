import '../../safety/domain/age_bracket.dart';

/// The master switch for **live** user-to-user features (cosmetic trading and
/// friendly contests).
///
/// It is now **on by default** for this build (a personal, not-yet-publicly-live
/// side project — the operator accepted the residual legal/ops risk documented in
/// `docs/legal/OPEN-ITEMS.md`). It stays a compile-time flag via
/// `bool.fromEnvironment` so a build can force it back off with
/// `--dart-define=SOCIAL_LIVE=false` — and, being environment-sourced rather than
/// a literal `const`, the off-path gating branches never become `dead_code`.
///
/// Turning this on does **not** remove the real safety locks that sit in series
/// with it: the server-enforced age band (migration 0013 — under-13 can never
/// reach social however the client is built), and the launch-market geo-gate
/// (`SocialLaunchGate` / `LAUNCH_MARKETS`, off outside cleared markets).
const bool kSocialLive = bool.fromEnvironment('SOCIAL_LIVE', defaultValue: true);

/// Safe-play rules, translated one-for-one from
/// `docs/08-ethics-privacy-safety.md` into pure, testable guards. Every Phase 3
/// surface must route its decisions through these — the rules live in code (and
/// in `test/social/safe_play_test.dart`), not just in intent.
class SafePlay {
  const SafePlay._();

  /// Item `type`s that can never be traded regardless of any other flag —
  /// nothing that confers power, consumption, or currency may change hands
  /// (docs 09 "cosmetic and optional only"; 04 §Grooming "purely cosmetic").
  static const Set<String> _nonTradableTypes = {
    'food',
    'consumable',
    'currency',
    'buff',
    'power',
  };

  /// Reward kinds a contest may grant. Deliberately cosmetic/progression only —
  /// never stats, power, or currency (04 §Friendly PvP: rewards are
  /// "cosmetic/progression, never power that snowballs").
  static const Set<String> _cosmeticRewardKinds = {
    'cosmetic',
    'collar',
    'decor',
    'title',
    'badge',
    'sticker',
  };

  /// The fixed, pre-moderated vocabulary of kind reactions. There is **no
  /// free-text chat** between players until moderation is staffed (08-ethics
  /// §Minors "no open chat in v1"); players may only send one of these.
  static const List<String> kSafeReactions = [
    '👋 Hello!',
    '💛 Love your cat',
    '✨ So cute',
    '🎉 Nice catch',
    '🐾 Paw five',
    '😊 Thanks!',
  ];

  /// Only genuinely cosmetic items may be traded. A non-cosmetic item, or any
  /// power/consumable/currency type, is never tradable — this is the structural
  /// no-real-money / no-pay-to-win guarantee for trading.
  static bool itemIsTradable({required bool isCosmetic, required String type}) =>
      isCosmetic && !_nonTradableTypes.contains(type.toLowerCase());

  /// A contest reward is allowed only if its kind is cosmetic/progression.
  static bool rewardIsCosmeticOnly(String rewardKind) =>
      _cosmeticRewardKinds.contains(rewardKind.toLowerCase());

  /// A coordinate is "coarse" when it is absent or fuzzed to <= 3 decimal places
  /// (~110 m) — the only precision the app ever persists (ADR 0001 / data
  /// model). A finer value would mean a precise location leaked in.
  static bool isCoarseCoordinate(double? value) {
    if (value == null) return true;
    final rounded = (value * 1000).round() / 1000;
    return (value - rounded).abs() < 1e-9;
  }

  /// A cat may be shown in a showcase only if it carries no precise location —
  /// we never build a registry of where a real cat lives (08-ethics R6).
  static bool showcaseIsLocationSafe({double? lat, double? lng}) =>
      isCoarseCoordinate(lat) && isCoarseCoordinate(lng);

  /// Any interaction with another player requires both the capability (age gate)
  /// and an accepted friendship — interaction is friends-only by design, never
  /// with strangers (08-ethics §Minors "safe social surfaces").
  static bool interactionAllowed(
    SocialCapabilities caps, {
    required bool otherIsFriend,
  }) =>
      caps.canUseSocial && otherIsFriend;

  /// Whether the player may use adults-only cat-keeper discovery — the one
  /// surface that reaches beyond a known friend code. Allowed only for an adult
  /// while live social is on (the [SocialCapabilities.canDiscover] gate); a minor
  /// is never surfaced to, or shown, a stranger (08-ethics §Minors; ADR 0004).
  static bool discoveryAllowed(SocialCapabilities caps) => caps.canDiscover;

  /// Whether the given text is an allowed message (i.e. one of the canned
  /// reactions). Free-text always fails — the guard rejects anything not in the
  /// fixed vocabulary.
  static bool isAllowedMessage(String text) => kSafeReactions.contains(text);
}
