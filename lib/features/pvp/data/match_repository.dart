import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../../social/domain/safe_play.dart';
import '../domain/cat_stats.dart';
import '../domain/contest_resolution.dart';
import '../domain/match.dart';
import '../domain/match_outcome.dart';

/// The client half of the friendly-contest backend (migrations 0012 + 0013).
/// Every state change goes through a server RPC that re-validates friends-only,
/// age (teen+adult only — under-13 can never enter), moderation, and block state
/// — the client never writes `matches` directly (there is no client write policy).
///
/// Gated by [kSocialLive]: while the master switch is off, these methods short
/// out with [MatchOutcome.restricted] and never touch the network, so no live
/// contest can start before the moderation + realtime groundwork is signed off
/// (ADR 0004). The logic is built and ready for the flag to flip.
class MatchRepository {
  MatchRepository(this._ref);

  final Ref _ref;

  String? get _uid =>
      _ref.read(supabaseClientProvider).auth.currentUser?.id;

  /// Challenge an accepted friend to a friendly contest.
  Future<MatchOutcome> challenge(String opponentId, MatchMode mode) async {
    if (!kSocialLive) return MatchOutcome.restricted;
    final result =
        await _ref.read(supabaseClientProvider).rpc('propose_match', params: {
      'p_opponent': opponentId,
      'p_mode': mode.token,
    });
    return MatchOutcome.fromToken(result as String?);
  }

  /// Accept or decline an open invite addressed to the caller.
  Future<MatchOutcome> respond(String matchId, {required bool accept}) async {
    if (!kSocialLive) return MatchOutcome.restricted;
    final result =
        await _ref.read(supabaseClientProvider).rpc('respond_match', params: {
      'p_match_id': matchId,
      'p_accept': accept,
    });
    return MatchOutcome.fromToken(result as String?);
  }

  /// Withdraw an invite the caller sent that hasn't been answered.
  Future<MatchOutcome> cancel(String matchId) async {
    if (!kSocialLive) return MatchOutcome.restricted;
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc('cancel_match', params: {'p_match_id': matchId});
    return MatchOutcome.fromToken(result as String?);
  }

  /// Record the friendly outcome of an accepted match. [winnerId] may be null
  /// for a draw; it grants no reward — the result is a keepsake, not power.
  Future<MatchOutcome> recordResult(String matchId, String? winnerId) async {
    if (!kSocialLive) return MatchOutcome.restricted;
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc('set_match_result', params: {
      'p_match_id': matchId,
      'p_winner': winnerId,
    });
    return MatchOutcome.fromToken(result as String?);
  }

  /// Auto-resolve an accepted match from the two cats' derived [CatStats] and
  /// record the computed result — no human picks the winner. The resolution is
  /// deterministic and takes no purchase lever ([ContestResolver]), so the
  /// contest is provably no-pay-to-win end to end. [challengerStats] belongs to
  /// [Match.challengerId], [opponentStats] to [Match.opponentId]. Returns the
  /// resolution alongside the RPC outcome so the caller can show an honest recap.
  Future<({MatchOutcome outcome, ContestResolution resolution})> autoResolve(
    Match match, {
    required CatStats challengerStats,
    required CatStats opponentStats,
  }) async {
    final mode = match.mode;
    final resolution = ContestResolver.resolve(
      mode ?? MatchMode.zoomies,
      challenger: challengerStats,
      opponent: opponentStats,
    );
    final winnerId = switch (resolution.winner) {
      ContestParty.challenger => match.challengerId,
      ContestParty.opponent => match.opponentId,
      ContestParty.draw => null,
    };
    final outcome = await recordResult(match.id, winnerId);
    return (outcome: outcome, resolution: resolution);
  }

  /// Open invites addressed to the caller (waiting on their answer). Empty while
  /// [kSocialLive] is off.
  Future<List<Match>> incoming() async {
    if (!kSocialLive) return const [];
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('matches')
        .select('id, mode, challenger_id, opponent_id, status, winner_id')
        .eq('opponent_id', uid)
        .eq('status', 'invited')
        .order('created_at', ascending: false);
    return _parse(rows);
  }

  /// Invites the caller has sent that are still open. Empty while off.
  Future<List<Match>> outgoing() async {
    if (!kSocialLive) return const [];
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('matches')
        .select('id, mode, challenger_id, opponent_id, status, winner_id')
        .eq('challenger_id', uid)
        .eq('status', 'invited')
        .order('created_at', ascending: false);
    return _parse(rows);
  }

  /// A live stream of every match the caller is a party to (RLS scopes the rows
  /// to their own), so invite/accept/result transitions surface without a manual
  /// refresh — the realtime half of the friendly-contest backend (migration
  /// 0012 puts `matches` on the realtime publication). Emits a single empty list
  /// while [kSocialLive] is off, so nothing subscribes to the network then.
  Stream<List<Match>> matchesStream() {
    if (!kSocialLive) return Stream.value(const []);
    return _ref
        .read(supabaseClientProvider)
        .from('matches')
        .stream(primaryKey: ['id']).map(_parse);
  }

  List<Match> _parse(dynamic rows) => (rows as List)
      .map((r) => Match.fromMap(Map<String, dynamic>.from(r as Map)))
      .toList();
}

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(ref),
);

/// The caller's open incoming + outgoing invites, for the matches screen.
final incomingMatchesProvider = FutureProvider.autoDispose<List<Match>>(
  (ref) => ref.read(matchRepositoryProvider).incoming(),
);
final outgoingMatchesProvider = FutureProvider.autoDispose<List<Match>>(
  (ref) => ref.read(matchRepositoryProvider).outgoing(),
);

/// A live view of all of the caller's matches, updated in realtime. Empty while
/// [kSocialLive] is off.
final liveMatchesProvider = StreamProvider.autoDispose<List<Match>>(
  (ref) => ref.watch(matchRepositoryProvider).matchesStream(),
);
