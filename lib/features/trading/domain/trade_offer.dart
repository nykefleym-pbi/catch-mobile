import 'package:flutter/foundation.dart';

import '../../social/domain/safe_play.dart';

/// One line of a trade: a quantity of a single cosmetic item.
@immutable
class TradeItem {
  const TradeItem({required this.itemId, required this.qty});

  final String itemId;
  final int qty;

  Map<String, dynamic> toJson() => {'item_id': itemId, 'qty': qty};

  static TradeItem? fromJson(Map<String, dynamic> map) {
    final id = map['item_id'];
    final rawQty = map['qty'];
    final qty = rawQty is int ? rawQty : int.tryParse('$rawQty');
    if (id is! String || id.isEmpty || qty == null) return null;
    return TradeItem(itemId: id, qty: qty);
  }
}

/// A proposed cosmetic swap between two friends. Mirrors the `trades.offer`
/// jsonb shape the server RPCs read (migration 0010): `from` are the items the
/// proposer gives, `to` are the items the recipient gives. This is the client
/// mirror of the server's `_trade_offer_ok` gate — the server re-validates
/// everything, but validating here first keeps the UI honest and avoids sending
/// an obviously-bad offer.
@immutable
class TradeOffer {
  const TradeOffer({required this.from, required this.to});

  final List<TradeItem> from;
  final List<TradeItem> to;

  Map<String, dynamic> toJson() => {
        'from': [for (final i in from) i.toJson()],
        'to': [for (final i in to) i.toJson()],
      };

  factory TradeOffer.fromJson(Map<String, dynamic> map) {
    List<TradeItem> parse(dynamic raw) {
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map)
            if (TradeItem.fromJson(Map<String, dynamic>.from(e))
                case final item?)
              item,
      ];
    }

    return TradeOffer(from: parse(map['from']), to: parse(map['to']));
  }

  Iterable<String> get allItemIds =>
      [for (final i in from) i.itemId, for (final i in to) i.itemId];

  bool get _hasDuplicateItem {
    final ids = allItemIds.toList();
    return ids.toSet().length != ids.length;
  }

  /// Structural validity, matching the server's `bad_offer` checks: at least one
  /// side is non-empty, every quantity is positive, and no item id appears twice
  /// across the whole offer.
  bool get isStructurallyValid {
    if (from.isEmpty && to.isEmpty) return false;
    for (final i in [...from, ...to]) {
      if (i.itemId.isEmpty || i.qty <= 0) return false;
    }
    return !_hasDuplicateItem;
  }

  /// The cosmetic-only safety check, using a caller-supplied lookup of item
  /// metadata (from the `items` catalogue). Every referenced item must be
  /// tradable per [SafePlay.itemIsTradable]; an unknown item is never tradable.
  /// The server enforces the same rule — this just fails fast client-side.
  bool isCosmeticSafe(({bool isCosmetic, String type})? Function(String) lookup) {
    for (final id in allItemIds) {
      final meta = lookup(id);
      if (meta == null) return false;
      if (!SafePlay.itemIsTradable(
        isCosmetic: meta.isCosmetic,
        type: meta.type,
      )) {
        return false;
      }
    }
    return true;
  }
}
