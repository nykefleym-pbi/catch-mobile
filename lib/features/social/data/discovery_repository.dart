import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/discovery_profile.dart';
import '../domain/safe_play.dart';

/// The client half of adults-only, opt-in cat-keeper discovery (migration 0022).
///
/// Both calls go through guarded SECURITY DEFINER RPCs that re-enforce the
/// adults-only + mutual-opt-in + block/dedup rules server-side — the client
/// never reads other profiles directly. Gated by [kSocialLive]: while the master
/// switch is off, both short out without a network call, so no cross-user
/// discovery can happen before the safeguards are signed off (ADR 0004).
class DiscoveryRepository {
  DiscoveryRepository(this._ref);

  final Ref _ref;

  /// The opted-in adult pool the caller may browse (safe fields only). Empty
  /// while [kSocialLive] is off, or when the caller is ineligible (the server
  /// returns an empty set — it never says why).
  Future<List<DiscoveryProfile>> list() async {
    if (!kSocialLive) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .rpc('list_discovery_profiles');
    return (rows as List)
        .map((r) => DiscoveryProfile.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Send a friend request to a discovered keeper. Returns the same status token
  /// vocabulary as the friend-code path (ok / exists / blocked / rate_limited /
  /// not_found / self / not_eligible / unauthenticated), since the server
  /// delegates to `friend_request_by_code` after the adults-only eligibility
  /// check. `restricted` is returned locally while live social is off.
  Future<String> add(String targetId) async {
    if (!kSocialLive) return 'restricted';
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc('discovery_add', params: {'p_target': targetId});
    return result as String? ?? 'error';
  }
}

final discoveryRepositoryProvider =
    Provider<DiscoveryRepository>((ref) => DiscoveryRepository(ref));

/// The discoverable adult pool. Auto-disposes so it refreshes on each open;
/// invalidate after opting in or sending a request. Empty while [kSocialLive]
/// is off.
final discoveryProfilesProvider =
    FutureProvider.autoDispose<List<DiscoveryProfile>>(
  (ref) => ref.read(discoveryRepositoryProvider).list(),
);
