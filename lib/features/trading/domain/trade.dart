import 'package:flutter/foundation.dart';

import 'trade_offer.dart';

/// A trade row as read back from the `trades` table (RLS scopes reads to the
/// two parties). The offer is parsed into a [TradeOffer]; status mirrors the
/// `trades.status` check constraint.
@immutable
class Trade {
  const Trade({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.offer,
    required this.status,
  });

  final String id;
  final String fromId;
  final String toId;
  final TradeOffer offer;
  final String status;

  bool get isProposed => status == 'proposed';

  /// Whether [viewerId] is the recipient who can accept/decline this proposal.
  bool incomingFor(String viewerId) => toId == viewerId && isProposed;

  factory Trade.fromMap(Map<String, dynamic> map) {
    final rawOffer = map['offer'];
    return Trade(
      id: map['id'] as String,
      fromId: map['from_id'] as String,
      toId: map['to_id'] as String,
      offer: rawOffer is Map
          ? TradeOffer.fromJson(Map<String, dynamic>.from(rawOffer))
          : const TradeOffer(from: [], to: []),
      status: (map['status'] as String?) ?? 'proposed',
    );
  }
}
