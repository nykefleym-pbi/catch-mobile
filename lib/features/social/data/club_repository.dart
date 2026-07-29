import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/club.dart';
import '../domain/safe_play.dart';

/// Clubs + cooperative challenges (roadmap p3c) — small, friends-based groups
/// working toward gentle shared goals. Every read and write flows through the
/// guarded SECURITY DEFINER RPCs in migration 0016 (friends-only invites, no
/// stranger-identity leak, age-gated, no chat, no pay-to-win).
///
/// The whole surface is held behind [kSocialLive]: while off, reads return empty
/// (no network) and mutations short-circuit to [ClubOutcome.restricted], so no
/// live user-to-user interaction happens until the master switch flips.
class ClubRepository {
  ClubRepository(this._ref);

  final Ref _ref;

  Future<List<Club>> myClubs() async {
    if (!kSocialLive) return const [];
    final rows = await _ref.read(supabaseClientProvider).rpc('list_my_clubs');
    return (rows as List)
        .map((r) => Club.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<ClubMember>> members(String clubId) async {
    if (!kSocialLive) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .rpc('list_club_members', params: {'p_club': clubId});
    return (rows as List)
        .map((r) => ClubMember.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Creates a club. Returns the outcome and, on success, the new club id.
  Future<(ClubOutcome, String?)> create(String name) async {
    if (!kSocialLive) return (ClubOutcome.restricted, null);
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc('create_club', params: {'p_name': name}) as String?;
    final outcome = ClubOutcome.parse(result);
    // create_club returns the new club's uuid (not a known token) on success.
    if (outcome == ClubOutcome.unknown && result != null) {
      return (ClubOutcome.ok, result);
    }
    return (outcome, null);
  }

  Future<ClubOutcome> invite(String clubId, String friendId) =>
      _call('invite_to_club', {'p_club': clubId, 'p_friend': friendId});

  Future<ClubOutcome> respondInvite(String clubId, {required bool accept}) =>
      _call('respond_club_invite', {'p_club': clubId, 'p_accept': accept});

  Future<ClubOutcome> leave(String clubId) =>
      _call('leave_club', {'p_club': clubId});

  Future<ClubOutcome> startChallenge(
          String clubId, ClubChallengeKind kind, int goal) =>
      _call('start_club_challenge',
          {'p_club': clubId, 'p_kind': kind.token, 'p_goal': goal});

  Future<ClubOutcome> contribute(String clubId) =>
      _call('club_contribute', {'p_club': clubId});

  Future<ClubOutcome> _call(String fn, Map<String, dynamic> params) async {
    if (!kSocialLive) return ClubOutcome.restricted;
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc(fn, params: params) as String?;
    return ClubOutcome.parse(result);
  }
}

final clubRepositoryProvider =
    Provider<ClubRepository>((ref) => ClubRepository(ref));

/// The player's clubs (active + invited). Empty while [kSocialLive] is off.
final myClubsProvider = FutureProvider.autoDispose<List<Club>>(
  (ref) => ref.read(clubRepositoryProvider).myClubs(),
);

/// A club's roster, keyed by club id. Empty while [kSocialLive] is off.
final clubMembersProvider =
    FutureProvider.autoDispose.family<List<ClubMember>, String>(
  (ref, clubId) => ref.read(clubRepositoryProvider).members(clubId),
);
