import 'package:flutter/foundation.dart';

/// A coarse, self-declared age band captured by the neutral onboarding gate.
///
/// This is the regulatory keystone (ADR 0003 / ADR 0004): social surfaces are
/// deferred to Phase 3 precisely because they engage COPPA / GDPR-K / UK-AADC,
/// so who can see them is driven by this band, not by an afterthought toggle.
/// It is intentionally *coarse* — no birthdate is stored (data-minimization) —
/// and the value maps 1:1 to the `profiles.age_bracket` column.
enum AgeBracket {
  under13,
  teen,
  adult,

  /// A player who onboarded before the gate existed, or hasn't answered yet.
  /// Treated as conservatively as `under13` for social access.
  unknown;

  /// The stored/serialised token (matches `profiles.age_bracket`).
  String get token => switch (this) {
        AgeBracket.under13 => 'under13',
        AgeBracket.teen => 'teen',
        AgeBracket.adult => 'adult',
        AgeBracket.unknown => 'unknown',
      };

  static AgeBracket fromToken(String? token) => switch (token) {
        'under13' => AgeBracket.under13,
        'teen' => AgeBracket.teen,
        'adult' => AgeBracket.adult,
        _ => AgeBracket.unknown,
      };

  /// Anyone under 18 is a minor and gets the conservative defaults.
  bool get isMinor => this == AgeBracket.under13 || this == AgeBracket.teen;
}

/// What a player is *allowed* to do on social surfaces, derived purely from their
/// [AgeBracket] and the master [socialLive] switch. This is a capability gate
/// (may they?), separate from any per-player preference (do they want to?).
///
/// The rules encode the enforceable requirements in
/// `docs/08-ethics-privacy-safety.md` §Minors:
/// - **under-13 / unknown** → reduced-data mode: no social at all.
/// - **13–17 (teen)** → friends allowed, but a showcase can never be made public
///   (forced private), and no trading.
/// - **18+ (adult)** → may opt into every surface, still gated by [socialLive].
@immutable
class SocialCapabilities {
  const SocialCapabilities({
    required this.canUseSocial,
    required this.canAddFriends,
    required this.canShowcaseToFriends,
    required this.canTrade,
    required this.canCompete,
  });

  /// The whole social hub is available.
  final bool canUseSocial;

  /// May send/accept friend requests.
  final bool canAddFriends;

  /// May turn on the opt-in, friends-only cat showcase (never public).
  final bool canShowcaseToFriends;

  /// May take part in cosmetic trading (also gated by the master switch).
  final bool canTrade;

  /// May take part in friendly, no-harm contests (also gated by the switch).
  final bool canCompete;

  static const SocialCapabilities none = SocialCapabilities(
    canUseSocial: false,
    canAddFriends: false,
    canShowcaseToFriends: false,
    canTrade: false,
    canCompete: false,
  );

  /// [socialLive] is the master switch for live trading / contests; it defaults
  /// to `false` so the pure rules are testable without importing app config.
  factory SocialCapabilities.forBracket(
    AgeBracket bracket, {
    bool socialLive = false,
  }) {
    switch (bracket) {
      case AgeBracket.adult:
        return SocialCapabilities(
          canUseSocial: true,
          canAddFriends: true,
          canShowcaseToFriends: true,
          canTrade: socialLive,
          canCompete: socialLive,
        );
      case AgeBracket.teen:
        return SocialCapabilities(
          canUseSocial: true,
          canAddFriends: true,
          canShowcaseToFriends: false, // minors: showcase forced private
          canTrade: false,
          canCompete: socialLive,
        );
      case AgeBracket.under13:
      case AgeBracket.unknown:
        return SocialCapabilities.none;
    }
  }
}
