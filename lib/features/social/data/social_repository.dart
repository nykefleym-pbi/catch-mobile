import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/friend.dart';
import '../domain/safe_play.dart';
import '../domain/showcase_cat.dart';

/// The friend graph + showcase settings for the social hub (Phase 3 groundwork).
///
/// Friend lookups go through the `friend_request_by_code` / `list_friends` RPCs
/// so no cross-user profile read is ever needed — profiles stay self-access and
/// only a short, rotatable code is ever shared (data-minimization, ADR 0004).
class SocialRepository {
  SocialRepository(this._ref);

  final Ref _ref;

  String? get _uid => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  // --- Friend code + showcase settings (live on profiles.settings) ----------

  Future<Map<String, dynamic>> _settings() async {
    final uid = _uid;
    if (uid == null) return {};
    final row = await _ref
        .read(supabaseClientProvider)
        .from('profiles')
        .select('settings')
        .eq('id', uid)
        .maybeSingle();
    final raw = row?['settings'];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  Future<void> _mergeSettings(Map<String, dynamic> patch) async {
    final uid = _uid;
    if (uid == null) return;
    final next = (await _settings())..addAll(patch);
    await _ref
        .read(supabaseClientProvider)
        .from('profiles')
        .update({'settings': next}).eq('id', uid);
  }

  /// The player's stable friend code, generated (and persisted) on first read.
  Future<String> friendCode() async {
    final settings = await _settings();
    final existing = settings['friend_code'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final code = _generateCode();
    await _mergeSettings({'friend_code': code});
    return code;
  }

  Future<bool> showcaseToFriends() async {
    final settings = await _settings();
    return settings['showcase_to_friends'] == true;
  }

  Future<void> setShowcaseToFriends(bool value) =>
      _mergeSettings({'showcase_to_friends': value});

  /// Whether the player has opted into adults-only cat-keeper discovery. Off by
  /// default; the server (`discovery_eligible`) is the real gate and only ever
  /// treats an adult as eligible, regardless of this local flag.
  Future<bool> discoveryOptIn() async {
    final settings = await _settings();
    return settings['discovery_opt_in'] == true;
  }

  Future<void> setDiscoveryOptIn(bool value) =>
      _mergeSettings({'discovery_opt_in': value});

  // --- Friend graph (via RPCs + RLS-guarded updates) ------------------------

  /// Returns a status token: ok / not_found / self / blocked / exists /
  /// unauthenticated.
  Future<String> requestByCode(String code) async {
    final result = await _ref
        .read(supabaseClientProvider)
        .rpc('friend_request_by_code', params: {'code': code});
    return result as String? ?? 'error';
  }

  Future<List<Friend>> friends() async {
    final rows =
        await _ref.read(supabaseClientProvider).rpc('list_friends');
    return (rows as List)
        .map((r) => Friend.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Accept or decline an incoming request from [friendId].
  Future<void> respond(String friendId, {required bool accept}) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref
        .read(supabaseClientProvider)
        .from('friendships')
        .update({
          'status': accept ? 'accepted' : 'declined',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('requester_id', friendId)
        .eq('addressee_id', uid);
  }

  /// Remove a friendship (either direction).
  Future<void> remove(String friendId) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref.read(supabaseClientProvider).from('friendships').delete().or(
          'and(requester_id.eq.$uid,addressee_id.eq.$friendId),'
          'and(requester_id.eq.$friendId,addressee_id.eq.$uid)',
        );
  }

  // --- Visiting (read a friend's showcase) ----------------------------------

  /// The cats a friend has chosen to showcase, via the guarded
  /// `list_friend_showcase` RPC (migration 0014) — the server checks the accepted
  /// friendship, block state, the viewer's age, and the owner's adult-only
  /// showcase flag, and returns only safe, non-location fields. Gated by
  /// [kSocialLive]: empty (no network) while live social is off.
  Future<List<ShowcaseCat>> friendShowcase(String friendId) async {
    if (!kSocialLive) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .rpc('list_friend_showcase', params: {'p_friend': friendId});
    return (rows as List)
        .map((r) => ShowcaseCat.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  static String _generateCode() {
    // Unambiguous alphabet (no 0/O/1/I) — easy to read aloud and type.
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => alphabet[rng.nextInt(alphabet.length)])
        .join();
  }
}

final socialRepositoryProvider =
    Provider<SocialRepository>((ref) => SocialRepository(ref));

/// The player's friends + pending requests. Auto-disposes so the hub refreshes
/// on each open; invalidate after a mutation.
final friendsProvider = FutureProvider.autoDispose<List<Friend>>(
  (ref) => ref.read(socialRepositoryProvider).friends(),
);

/// A friend's showcased cats, keyed by friend id. Empty while [kSocialLive] is
/// off (the repository short-circuits without a network call).
final friendShowcaseProvider =
    FutureProvider.autoDispose.family<List<ShowcaseCat>, String>(
  (ref, friendId) => ref.read(socialRepositoryProvider).friendShowcase(friendId),
);
