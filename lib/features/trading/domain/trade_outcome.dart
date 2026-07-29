/// The result string returned by the trade RPCs (migration 0010:
/// `propose_trade`, `execute_trade`, `set_trade_status`). Parsing it into a
/// typed value keeps the UI honest about *why* a trade didn't go through —
/// never pretending a rejected or rate-limited trade succeeded.
enum TradeOutcome {
  ok('ok'),
  notFound('not_found'),
  notProposed('not_proposed'),
  notParty('not_party'),
  notFriends('not_friends'),
  blocked('blocked'),
  restricted('restricted'),
  notCosmetic('not_cosmetic'),
  insufficient('insufficient'),
  badOffer('bad_offer'),
  badTarget('bad_target'),
  badStatus('bad_status'),
  rateLimited('rate_limited'),
  unauthenticated('unauthenticated'),
  unknown('unknown');

  const TradeOutcome(this.token);

  final String token;

  static TradeOutcome fromToken(String? token) {
    for (final o in TradeOutcome.values) {
      if (o.token == token) return o;
    }
    return TradeOutcome.unknown;
  }

  bool get isSuccess => this == TradeOutcome.ok;

  /// A gentle, player-facing explanation. Never blames the player; always says
  /// what to do next where there is something to do.
  String get message => switch (this) {
        TradeOutcome.ok => 'Done! 🐾',
        TradeOutcome.notFound => 'That trade is no longer available.',
        TradeOutcome.notProposed => 'That trade has already been handled.',
        TradeOutcome.notParty => 'This trade isn\'t yours to act on.',
        TradeOutcome.notFriends =>
          'You can only trade with accepted friends.',
        TradeOutcome.blocked => 'You can\'t trade with this player.',
        TradeOutcome.restricted =>
          'Trading isn\'t available on your account right now.',
        TradeOutcome.notCosmetic =>
          'Only cosmetic items can be traded — never anything you play with or '
              'win with.',
        TradeOutcome.insufficient =>
          'Someone no longer has one of these items. Nothing was traded.',
        TradeOutcome.badOffer => 'That offer isn\'t valid. Please adjust it.',
        TradeOutcome.badTarget => 'Choose a friend to trade with.',
        TradeOutcome.badStatus => 'That action isn\'t allowed here.',
        TradeOutcome.rateLimited =>
          'That\'s a lot of trades in a short time — try again a little later.',
        TradeOutcome.unauthenticated => 'Please sign in to trade.',
        TradeOutcome.unknown =>
          'Something went wrong with that trade. Please try again.',
      };
}
