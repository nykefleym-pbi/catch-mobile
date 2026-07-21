import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/safe_play.dart';
import '../domain/trade.dart';

/// Cosmetic trading (roadmap p3d). Charms (migration 0017) are ownable
/// `inventory` rows; every trade flows through the atomic, cosmetic-only-
/// re-validating RPCs in migration 0010 (`propose_trade` / `execute_trade` /
/// `set_trade_status`), which enforce friends-only + block + moderation gating
/// server-side. This client never sees a friend's inventory: a request is built
/// from the public charm catalogue and validated against the recipient's stock
/// only at accept time.
///
/// The whole surface is held behind [kSocialLive]: while off, reads return empty
/// (no network) and mutations short-circuit to [TradeOutcome.restricted].
class TradeRepository {
  TradeRepository(this._ref);

  final Ref _ref;

  String? get _uid => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  /// The player's own cosmetic charms (quantity > 0).
  Future<List<OwnedCosmetic>> myCharms() async {
    if (!kSocialLive) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('inventory')
        .select('quantity, items!inner(id, label, type, is_cosmetic)')
        .eq('items.is_cosmetic', true)
        .gt('quantity', 0);
    return (rows as List)
        .map((r) => OwnedCosmetic.fromRow(Map<String, dynamic>.from(r as Map)))
        .where((c) => c.itemId.isNotEmpty)
        .toList();
  }

  /// Proposed trades the player is a party to (RLS scopes to their own trades).
  Future<List<Trade>> proposedTrades() async {
    if (!kSocialLive) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('trades')
        .select('id, from_id, to_id, status, offer, created_at')
        .eq('status', 'proposed')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Trade.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<TradeOutcome> propose(String toId, TradeOffer offer) async {
    if (!kSocialLive) return TradeOutcome.restricted;
    final result = await _ref.read(supabaseClientProvider).rpc(
      'propose_trade',
      params: {'p_to': toId, 'p_offer': offer.toJson()},
    ) as String?;
    return TradeOutcome.parse(result);
  }

  Future<TradeOutcome> accept(String tradeId) =>
      _call('execute_trade', {'p_trade_id': tradeId});

  Future<TradeOutcome> decline(String tradeId) => _call(
      'set_trade_status', {'p_trade_id': tradeId, 'p_status': 'declined'});

  Future<TradeOutcome> cancel(String tradeId) => _call(
      'set_trade_status', {'p_trade_id': tradeId, 'p_status': 'cancelled'});

  Future<TradeOutcome> _call(String fn, Map<String, dynamic> params) async {
    if (!kSocialLive) return TradeOutcome.restricted;
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc(fn, params: params) as String?;
    return TradeOutcome.parse(result);
  }

  /// A live stream of the caller's trades (RLS-scoped to trades they are a party
  /// to), so an incoming proposal appears without a manual refresh — the
  /// realtime half of the trade backend (migration 0010 puts `trades` on the
  /// realtime publication). Emits a single empty list while [kSocialLive] is off.
  Stream<List<Trade>> tradesStream() {
    if (!kSocialLive) return Stream.value(const []);
    return _ref
        .read(supabaseClientProvider)
        .from('trades')
        .stream(primaryKey: ['id']).map((rows) => rows
            .map((r) => Trade.fromRow(Map<String, dynamic>.from(r)))
            .toList());
  }

  String? get uid => _uid;
}

final tradeRepositoryProvider =
    Provider<TradeRepository>((ref) => TradeRepository(ref));

/// The player's charm collection. Empty while [kSocialLive] is off.
final myCharmsProvider = FutureProvider.autoDispose<List<OwnedCosmetic>>(
  (ref) => ref.read(tradeRepositoryProvider).myCharms(),
);

/// Proposed trades the player is a party to. Empty while [kSocialLive] is off.
final proposedTradesProvider = FutureProvider.autoDispose<List<Trade>>(
  (ref) => ref.read(tradeRepositoryProvider).proposedTrades(),
);

/// A live view of all of the caller's trades, updated in realtime. Empty while
/// [kSocialLive] is off.
final liveTradesProvider = StreamProvider.autoDispose<List<Trade>>(
  (ref) => ref.watch(tradeRepositoryProvider).tradesStream(),
);
