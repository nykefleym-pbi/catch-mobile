/// The result string returned by the match RPCs (migration 0012 +
/// 0013: `propose_match`, `respond_match`, `cancel_match`, `set_match_result`).
/// Parsing it keeps the UI honest about *why* a challenge didn't go through —
/// never pretending a rejected or age-gated challenge succeeded.
enum MatchOutcome {
  ok('ok'),
  badTarget('bad_target'),
  badMode('bad_mode'),
  ageRestricted('age_restricted'),
  restricted('restricted'),
  blocked('blocked'),
  notFriends('not_friends'),
  rateLimited('rate_limited'),
  notFound('not_found'),
  forbidden('forbidden'),
  closed('closed'),
  badWinner('bad_winner'),
  unauthenticated('unauthenticated'),
  unknown('unknown');

  const MatchOutcome(this.token);

  final String token;

  static MatchOutcome fromToken(String? token) {
    for (final o in MatchOutcome.values) {
      if (o.token == token) return o;
    }
    return MatchOutcome.unknown;
  }

  bool get isSuccess => this == MatchOutcome.ok;

  /// A gentle, player-facing explanation. Never blames the player; always says
  /// what to do next where there is something to do.
  String get message => switch (this) {
        MatchOutcome.ok => 'Done! 🐾',
        MatchOutcome.badTarget => 'Choose a friend to play with.',
        MatchOutcome.badMode => 'Pick a contest to play.',
        MatchOutcome.ageRestricted =>
          'Friendly contests are part of the older-guardian experience.',
        MatchOutcome.restricted =>
          'Contests aren\'t available on your account right now.',
        MatchOutcome.blocked => 'You can\'t play with this guardian.',
        MatchOutcome.notFriends =>
          'You can only play with accepted friends.',
        MatchOutcome.rateLimited =>
          'That\'s a lot of invites in a short time — try again a little later.',
        MatchOutcome.notFound => 'That contest is no longer available.',
        MatchOutcome.forbidden => 'This contest isn\'t yours to act on.',
        MatchOutcome.closed => 'That contest has already been handled.',
        MatchOutcome.badWinner => 'The result didn\'t look right — try again.',
        MatchOutcome.unauthenticated => 'Please sign in to play.',
        MatchOutcome.unknown =>
          'Something went wrong with that contest. Please try again.',
      };
}
