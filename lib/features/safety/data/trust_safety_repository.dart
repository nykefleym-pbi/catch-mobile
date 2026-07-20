import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/moderation.dart';
import '../domain/report_reason.dart';

/// The reporting + blocking primitives every shared surface routes through.
/// These MUST exist before any user-to-user interaction goes live
/// (docs/08-ethics-privacy-safety.md §Content moderation; R9). Reports go
/// through the server-side `submit_report` RPC (migration 0009), which is the
/// single anti-abuse gate — rate-limited, de-duplicated, and closed to
/// restricted accounts. There is no in-app moderation console (Phase 5 ops
/// tooling); blocks are enforced by RLS in the friends-only showcase policy.
class TrustSafetyRepository {
  TrustSafetyRepository(this._ref);

  final Ref _ref;

  String? get _uid =>
      _ref.read(supabaseClientProvider).auth.currentUser?.id;

  /// File a report through the hardened `submit_report` RPC. Returns the parsed
  /// [ReportOutcome] so the UI can be honest about rate limits / duplicates.
  Future<ReportOutcome> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? detail,
  }) async {
    if (_uid == null) return ReportOutcome.unauthenticated;
    final result =
        await _ref.read(supabaseClientProvider).rpc('submit_report', params: {
      'p_target_type': targetType.token,
      'p_target_id': targetId,
      'p_reason': reason.token,
      if (detail != null && detail.trim().isNotEmpty) 'p_detail': detail.trim(),
    });
    return ReportOutcome.fromToken(result as String?);
  }

  /// The current player's own active account restriction, if any. RLS scopes
  /// the read to their own row; returns null when unrestricted.
  Future<Restriction?> myRestriction() async {
    final uid = _uid;
    if (uid == null) return null;
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('restrictions')
        .select('kind, reason, expires_at')
        .eq('profile_id', uid);
    Restriction? active;
    for (final row in rows as List) {
      final r = Restriction.fromMap(Map<String, dynamic>.from(row as Map));
      if (r == null || !r.isActive) continue;
      // Prefer the most severe active restriction.
      if (active == null || r.kind.index > active.kind.index) active = r;
    }
    return active;
  }

  /// Block another player. Idempotent (primary key = (blocker, blocked)).
  Future<void> block(String blockedId) async {
    final uid = _uid;
    if (uid == null || uid == blockedId) return;
    await _ref.read(supabaseClientProvider).from('blocks').upsert(
      {'blocker_id': uid, 'blocked_id': blockedId},
      onConflict: 'blocker_id,blocked_id',
    );
  }

  Future<void> unblock(String blockedId) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref
        .read(supabaseClientProvider)
        .from('blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', blockedId);
  }

  /// The set of profile ids the current player has blocked.
  Future<Set<String>> blockedIds() async {
    final uid = _uid;
    if (uid == null) return {};
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', uid);
    return (rows as List)
        .map((r) => (r as Map)['blocked_id'] as String)
        .toSet();
  }
}

final trustSafetyRepositoryProvider = Provider<TrustSafetyRepository>(
  (ref) => TrustSafetyRepository(ref),
);

/// The current player's active account restriction (or null). Auto-disposes so
/// it re-checks when a social surface is opened; social actions consult this to
/// disable themselves client-side while the server enforces the same limit.
final myRestrictionProvider = FutureProvider.autoDispose<Restriction?>(
  (ref) => ref.read(trustSafetyRepositoryProvider).myRestriction(),
);
