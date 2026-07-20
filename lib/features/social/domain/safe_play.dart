import '../../safety/domain/age_bracket.dart';

/// The master switch for **live** user-to-user features (cosmetic trading and
/// friendly contests). It defaults to `false` and stays off until the backing
/// realtime + anti-abuse + moderation groundwork exists (ADR 0004, R9). While
/// off, those surfaces render an honest "coming when we can host it safely"
/// explainer rather than a simulated experience.
const bool kSocialLive = false;

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

  /// A coordinate is "coarse" when it is absent or fuzzed to <= 2 decimal places
  /// (~1.1 km) — the only precision the app ever persists (ADR 0001 / data
  /// model). A finer value would mean a precise location leaked in.
  static bool isCoarseCoordinate(double? value) {
    if (value == null) return true;
    final rounded = (value * 100).round() / 100;
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

  /// Whether the given text is an allowed message (i.e. one of the canned
  /// reactions). Free-text always fails — the guard rejects anything not in the
  /// fixed vocabulary.
  static bool isAllowedMessage(String text) => kSafeReactions.contains(text);
}
