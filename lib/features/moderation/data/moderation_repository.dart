import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/mod_report.dart';

/// The client half of the in-app moderation console (migration 0018). Every call
/// goes through an `authenticated`-callable `mod_*_v2` RPC that re-verifies the
/// caller is a registered moderator server-side before doing anything — a normal
/// player calling these gets `forbidden` or an empty queue and can never reach
/// the underlying service-role action layer (migration 0011). There is no
/// service key in the client.
///
/// This surface is intentionally NOT gated by `kSocialLive`: moderation must work
/// regardless of whether live social is on (reports can exist either way).
class ModerationRepository {
  ModerationRepository(this._ref);

  final Ref _ref;

  dynamic get _db => _ref.read(supabaseClientProvider);

  /// Whether the signed-in user may use the console (drives the entry point).
  Future<bool> amIModerator() async {
    final result = await _db.rpc('mod_am_i_moderator');
    return result == true;
  }

  /// The review queue, newest-first, most-flagged targets surfaced by count.
  Future<List<ModReport>> queue({int limit = 100}) async {
    final rows = await _db.rpc('mod_queue_v2', params: {'p_limit': limit});
    return (rows as List)
        .map((r) => ModReport.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Mark a report as under review so two moderators don't collide.
  Future<ModOutcome> claim(String reportId) async {
    final result =
        await _db.rpc('mod_claim_v2', params: {'p_report_id': reportId});
    return ModOutcome.parse(result as String?);
  }

  /// Resolve a report: log an action and optionally restrict the account.
  Future<ModOutcome> resolve({
    required String reportId,
    required ModActionKind action,
    String? reason,
    String? note,
    RestrictionKind restriction = RestrictionKind.none,
    int? days,
  }) async {
    final result = await _db.rpc('mod_resolve_v2', params: {
      'p_report_id': reportId,
      'p_action': action.token,
      'p_reason': reason,
      'p_note': note,
      'p_restriction_kind': restriction.param,
      'p_restriction_days': days,
    });
    return ModOutcome.parse(result as String?);
  }

  /// Lift a restriction early (audited as a 'lift').
  Future<ModOutcome> liftRestriction(String restrictionId, {String? reason}) async {
    final result = await _db.rpc('mod_lift_v2',
        params: {'p_restriction_id': restrictionId, 'p_reason': reason});
    return ModOutcome.parse(result as String?);
  }
}

final moderationRepositoryProvider =
    Provider<ModerationRepository>((ref) => ModerationRepository(ref));

/// Whether to show the console entry point for the signed-in user.
final amIModeratorProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(moderationRepositoryProvider).amIModerator(),
);

/// The current review queue.
final modQueueProvider = FutureProvider.autoDispose<List<ModReport>>(
  (ref) => ref.read(moderationRepositoryProvider).queue(),
);
