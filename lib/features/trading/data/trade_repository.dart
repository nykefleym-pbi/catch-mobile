import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../../social/domain/safe_play.dart';
import '../domain/trade.dart';
import '../domain/trade_offer.dart';
import '../domain/trade_outcome.dart';

/// The client half of the secure trade backend (migration 0010). Every state
/// change goes through a server RPC that re-validates cosmetic-only,
/// friends-only, moderation, and ownership — the client never writes `trades`
/// directly (the raw insert/update policies were dropped).
///
/// Gated by [kSocialLive]: while the master switch is off, these methods short
/// out with [TradeOutcome.restricted] and never call the network, so no live
/// trading can happen before the moderation + realtime groundwork is signed off
/// (ADR 0004). The logic is built and ready for the flag to flip.
class TradeRepository {
  TradeRepository(this._ref);

  final Ref _ref;

  Future<TradeOutcome> propose(String toProfileId, TradeOffer offer) async {
    if (!kSocialLive) return TradeOutcome.restricted;
    if (!offer.isStructurallyValid) return TradeOutcome.badOffer;
    final result =
        await _ref.read(supabaseClientProvider).rpc('propose_trade', params: {
      'p_to': toProfileId,
      'p_offer': offer.toJson(),
    });
    return TradeOutcome.fromToken(result as String?);
  }

  Future<TradeOutcome> accept(String tradeId) async {
    if (!kSocialLive) return TradeOutcome.restricted;
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc('execute_trade', params: {'p_trade_id': tradeId});
    return TradeOutcome.fromToken(result as String?);
  }

  Future<TradeOutcome> decline(String tradeId) => _setStatus(tradeId, 'declined');

  Future<TradeOutcome> cancel(String tradeId) => _setStatus(tradeId, 'cancelled');

  Future<TradeOutcome> _setStatus(String tradeId, String status) async {
    if (!kSocialLive) return TradeOutcome.restricted;
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc('set_trade_status', params: {
      'p_trade_id': tradeId,
      'p_status': status,
    });
    return TradeOutcome.fromToken(result as String?);
  }

  /// The caller's open (proposed) trades. Empty while [kSocialLive] is off.
  Future<List<Trade>> pending() async {
    if (!kSocialLive) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('trades')
        .select('id, from_id, to_id, offer, status')
        .eq('status', 'proposed')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Trade.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

final tradeRepositoryProvider = Provider<TradeRepository>(
  (ref) => TradeRepository(ref),
);
