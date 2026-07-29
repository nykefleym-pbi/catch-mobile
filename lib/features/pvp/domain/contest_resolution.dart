import 'package:flutter/foundation.dart';

import 'cat_stats.dart';
import 'match.dart';

/// Which side a resolved friendly contest went to. [draw] is a first-class,
/// happy result — a contest need not have a loser.
enum ContestParty { challenger, opponent, draw }

/// The outcome of auto-resolving a friendly contest, plus the numbers it was
/// decided on, so the UI can show an honest little "here's how it went" recap
/// instead of a bare winner. Nothing here is a reward — it is a keepsake.
@immutable
class ContestResolution {
  const ContestResolution({
    required this.mode,
    required this.winner,
    required this.decidedBy,
    required this.challengerScore,
    required this.opponentScore,
  });

  final MatchMode mode;

  /// The side that took the contest, or [ContestParty.draw].
  final ContestParty winner;

  /// The [CatStat] the result actually turned on — the mode's governing stat for
  /// a clear win, or a whole-cat tiebreak when the governing stats were level.
  final CatStat decidedBy;

  /// The two comparable scores (governing stat, or total on a tiebreak), kept so
  /// the recap can say *why* — never hidden, so the result never feels arbitrary.
  final int challengerScore;
  final int opponentScore;

  bool get isDraw => winner == ContestParty.draw;
}

/// Resolves a friendly contest **deterministically** from the two cats' derived
/// [CatStats] — the auto-resolver that replaces any manual winner entry.
///
/// **No pay-to-win is structural, not a promise.** [resolve] consumes only the
/// two [CatStats] (which themselves come solely from care, bond, growth, and
/// personality — see [CatStats.derive]) and the [MatchMode]. There is
/// deliberately *no* item, currency, purchase, or randomness parameter anywhere
/// in reach, so the only way to sway a result is to care for the cat. The
/// function is pure and symmetric: swapping the two cats mirrors the outcome,
/// and identical inputs always give a [ContestParty.draw]. `test/pvp/
/// contest_resolution_test.dart` guards every one of these properties.
class ContestResolver {
  const ContestResolver._();

  static ContestResolution resolve(
    MatchMode mode, {
    required CatStats challenger,
    required CatStats opponent,
  }) {
    final stat = mode.governingStat;
    final a = challenger[stat];
    final b = opponent[stat];
    if (a != b) {
      return ContestResolution(
        mode: mode,
        winner: a > b ? ContestParty.challenger : ContestParty.opponent,
        decidedBy: stat,
        challengerScore: a,
        opponentScore: b,
      );
    }

    // Level on the event's own stat — the all-round better-cared-for cat edges
    // it. Cuteness breaks a *total* tie last, because a happy, well-groomed cat
    // wins hearts; a perfect tie is a genuine draw.
    final ta = _total(challenger);
    final tb = _total(opponent);
    if (ta != tb) {
      return ContestResolution(
        mode: mode,
        winner: ta > tb ? ContestParty.challenger : ContestParty.opponent,
        decidedBy: CatStat.cuteness,
        challengerScore: ta,
        opponentScore: tb,
      );
    }

    return ContestResolution(
      mode: mode,
      winner: ContestParty.draw,
      decidedBy: stat,
      challengerScore: a,
      opponentScore: b,
    );
  }

  static int _total(CatStats s) {
    var t = 0;
    for (final stat in CatStat.values) {
      t += s[stat];
    }
    return t;
  }
}
