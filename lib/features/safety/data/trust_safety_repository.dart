import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/report_reason.dart';

/// The reporting + blocking primitives every shared surface routes through.
/// These MUST exist before any user-to-user interaction goes live
/// (docs/08-ethics-privacy-safety.md §Content moderation; R9). Reports land in
/// the owner-scoped `reports` table for out-of-band moderation (there is no
/// in-app console — that is Phase 5 ops tooling); blocks are enforced by RLS in
/// the friends-only showcase policy.
class TrustSafetyRepository {
  TrustSafetyRepository(this._ref);

  final Ref _ref;

  String? get _uid =>
      _ref.read(supabaseClientProvider).auth.currentUser?.id;

  /// File a report. RLS requires `reporter_id = auth.uid()`.
  Future<void> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? detail,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref.read(supabaseClientProvider).from('reports').insert({
      'reporter_id': uid,
      'target_type': targetType.token,
      'target_id': targetId,
      'reason': reason.token,
      if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
    });
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
