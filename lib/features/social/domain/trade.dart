import 'package:flutter/foundation.dart';

/// Display emoji for each catalogue charm (migration 0017). A charm the client
/// doesn't know yet still renders with a gentle fallback.
const Map<String, String> kCharmEmoji = {
  'charm_yarn': '🧶',
  'charm_fish': '🐟',
  'charm_bell': '🔔',
  'charm_star': '⭐',
  'charm_leaf': '🍃',
  'charm_moon': '🌙',
  'charm_heart': '💗',
  'charm_paw': '🐾',
};

/// The full catalogue of tradable charm ids, in display order — the denominator
/// for a "collect the set" view and the pool a trade request is built from.
const List<String> kCharmOrder = [
  'charm_yarn',
  'charm_fish',
  'charm_bell',
  'charm_star',
  'charm_leaf',
  'charm_moon',
  'charm_heart',
  'charm_paw',
];

String charmEmoji(String itemId) => kCharmEmoji[itemId] ?? '🎀';

/// A cosmetic item the player owns, with how many they hold. Cosmetic-only by
/// construction — charms grant no affection and touch no cat stat (no P2W).
@immutable
class OwnedCosmetic {
  const OwnedCosmetic({
    required this.itemId,
    required this.label,
    required this.quantity,
  });

  final String itemId;
  final String label;
  final int quantity;

  String get emoji => charmEmoji(itemId);

  /// From an `inventory` row that embeds its `items(...)`.
  factory OwnedCosmetic.fromRow(Map<String, dynamic> row) {
    final item = row['items'];
    final itemMap = item is Map ? Map<String, dynamic>.from(item) : const {};
    return OwnedCosmetic(
      itemId: (itemMap['id'] as String?) ?? '',
      label: (itemMap['label'] as String?) ?? 'Charm',
      quantity: (row['quantity'] as int?) ?? 0,
    );
  }
}

/// One line of a trade offer: how many of an item change hands.
@immutable
class OfferLine {
  const OfferLine({required this.itemId, required this.quantity});

  final String itemId;
  final int quantity;

  String get emoji => charmEmoji(itemId);
  String get label => _charmLabel(itemId);

  Map<String, dynamic> toJson() => {'item_id': itemId, 'qty': quantity};

  factory OfferLine.fromJson(Map<String, dynamic> json) => OfferLine(
        itemId: (json['item_id'] as String?) ?? '',
        quantity: (json['qty'] as int?) ?? 0,
      );
}

/// A two-sided cosmetic trade offer. [give] are the items the proposer offers;
/// [request] are the items they'd like in return (validated against the
/// recipient's inventory only at accept time — a proposer never sees a friend's
/// inventory). Either side may be empty (a gift), but not both.
@immutable
class TradeOffer {
  const TradeOffer({this.give = const [], this.request = const []});

  final List<OfferLine> give;
  final List<OfferLine> request;

  bool get isEmpty => give.isEmpty && request.isEmpty;

  Map<String, dynamic> toJson() => {
        'from': [for (final l in give) l.toJson()],
        'to': [for (final l in request) l.toJson()],
      };
}

/// A proposed cosmetic trade between two friends, as read from the `trades`
/// table. From the viewer's perspective it is either incoming (they may accept
/// or decline) or outgoing (they may cancel).
@immutable
class Trade {
  const Trade({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.status,
    required this.give,
    required this.request,
  });

  final String id;
  final String fromId;
  final String toId;
  final String status;
  final List<OfferLine> give; // what fromId offers
  final List<OfferLine> request; // what fromId wants back

  bool isIncoming(String viewerId) => toId == viewerId;
  bool isOutgoing(String viewerId) => fromId == viewerId;

  /// The other party's id from the viewer's perspective.
  String otherId(String viewerId) => fromId == viewerId ? toId : fromId;

  factory Trade.fromRow(Map<String, dynamic> row) {
    final offer = row['offer'];
    final offerMap = offer is Map ? Map<String, dynamic>.from(offer) : const {};
    List<OfferLine> side(String key) {
      final raw = offerMap[key];
      return [
        if (raw is List)
          for (final e in raw)
            OfferLine.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    }

    return Trade(
      id: row['id'] as String,
      fromId: row['from_id'] as String,
      toId: row['to_id'] as String,
      status: (row['status'] as String?) ?? 'proposed',
      give: side('from'),
      request: side('to'),
    );
  }
}

/// The typed outcome of a trade RPC (migration 0010 status tokens).
enum TradeOutcome {
  ok,
  restricted,
  blocked,
  notFriends,
  badTarget,
  badOffer,
  notCosmetic,
  rateLimited,
  notFound,
  notProposed,
  notParty,
  insufficient,
  badStatus,
  unauthenticated,
  unknown;

  static TradeOutcome parse(String? token) => switch (token) {
        'ok' => TradeOutcome.ok,
        'restricted' => TradeOutcome.restricted,
        'blocked' => TradeOutcome.blocked,
        'not_friends' => TradeOutcome.notFriends,
        'bad_target' => TradeOutcome.badTarget,
        'bad_offer' => TradeOutcome.badOffer,
        'not_cosmetic' => TradeOutcome.notCosmetic,
        'rate_limited' => TradeOutcome.rateLimited,
        'not_found' => TradeOutcome.notFound,
        'not_proposed' => TradeOutcome.notProposed,
        'not_party' => TradeOutcome.notParty,
        'insufficient' => TradeOutcome.insufficient,
        'bad_status' => TradeOutcome.badStatus,
        'unauthenticated' => TradeOutcome.unauthenticated,
        _ => TradeOutcome.unknown,
      };

  bool get isSuccess => this == TradeOutcome.ok;

  String get message => switch (this) {
        TradeOutcome.ok => 'Done! 🐾',
        TradeOutcome.restricted => "That isn't available on your account.",
        TradeOutcome.blocked => "Can't trade with that person right now.",
        TradeOutcome.notFriends => 'You can only trade with an accepted friend.',
        TradeOutcome.badTarget => 'Please choose a friend to trade with.',
        TradeOutcome.badOffer => 'Please choose at least one charm to trade.',
        TradeOutcome.notCosmetic =>
          'Only cosmetic charms can be traded — never anything with power.',
        TradeOutcome.rateLimited =>
          "That's a lot of trades in a short time — try again a little later.",
        TradeOutcome.notFound => 'That trade is no longer here.',
        TradeOutcome.notProposed => 'That trade was already answered.',
        TradeOutcome.notParty => "That trade isn't yours to change.",
        TradeOutcome.insufficient =>
          "Someone doesn't have those charms anymore.",
        TradeOutcome.badStatus => 'That change isn\'t allowed.',
        TradeOutcome.unauthenticated => 'Please sign in first.',
        TradeOutcome.unknown => 'Something went wrong — try again.',
      };
}

String _charmLabel(String itemId) => switch (itemId) {
      'charm_yarn' => 'Yarn Ball',
      'charm_fish' => 'Little Fish',
      'charm_bell' => 'Jingle Bell',
      'charm_star' => 'Gold Star',
      'charm_leaf' => 'Lucky Leaf',
      'charm_moon' => 'Night Moon',
      'charm_heart' => 'Warm Heart',
      'charm_paw' => 'Paw Print',
      _ => 'Charm',
    };
