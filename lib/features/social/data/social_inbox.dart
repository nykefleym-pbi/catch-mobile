import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../../pvp/data/match_repository.dart';
import '../../pvp/domain/match.dart';
import '../domain/trade.dart';
import 'trade_repository.dart';

/// How many items are waiting on the player right now — incoming trade proposals
/// plus incoming match invites addressed to them. Pure so it is unit-testable
/// without a network: the realtime plumbing lives in [socialInboxCountProvider].
int socialInboxCount({
  required List<Trade> trades,
  required List<Match> matches,
  required String? uid,
}) {
  if (uid == null) return 0;
  final incomingTrades =
      trades.where((t) => t.status == 'proposed' && t.isIncoming(uid)).length;
  final incomingMatches = matches.where((m) => m.incomingFor(uid)).length;
  return incomingTrades + incomingMatches;
}

/// A live count of the player's pending social inbox (incoming trade proposals +
/// match invites), driven by the realtime trade/match streams. Zero while
/// `kSocialLive` is off (the streams emit empty) or when signed out. This is the
/// in-app "notification" signal — a badge, not a push (no push infra, and none
/// is sent to minors regardless).
final socialInboxCountProvider = Provider.autoDispose<int>((ref) {
  final trades = ref.watch(liveTradesProvider).valueOrNull ?? const <Trade>[];
  final matches = ref.watch(liveMatchesProvider).valueOrNull ?? const <Match>[];
  final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  return socialInboxCount(trades: trades, matches: matches, uid: uid);
});
