import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/care_state.dart';

/// Reads and writes a cat's [CareState]. RLS scopes every query to the signed-in
/// user, so no explicit `profile_id` filter is needed on reads.
class CareRepository {
  CareRepository(this._ref);

  final Ref _ref;

  static const _columns = 'cat_id, hunger, happiness, mood, last_updated';

  Future<CareState> fetch(String catId) async {
    final client = _ref.read(supabaseClientProvider);
    final row = await client
        .from('care_state')
        .select(_columns)
        .eq('cat_id', catId)
        .maybeSingle();
    final friendship = await _fetchFriendship(catId);
    if (row == null) return CareState.initial(catId, friendship: friendship);
    return CareState.fromMap(Map<String, dynamic>.from(row), friendship: friendship);
  }

  /// Persists [next]: the needs go to `care_state` (upsert on the `cat_id`
  /// primary key) and the bond to `cats.friendship_level`. Returns the stored
  /// state so the UI reflects exactly what the database now holds.
  Future<CareState> persist(CareState next) async {
    final client = _ref.read(supabaseClientProvider);
    final profileId = client.auth.currentUser?.id;
    final row = await client
        .from('care_state')
        .upsert(next.toRow(profileId), onConflict: 'cat_id')
        .select(_columns)
        .single();
    final catRow = await client
        .from('cats')
        .update({'friendship_level': next.friendship})
        .eq('id', next.catId)
        .select('friendship_level')
        .single();
    final friendship =
        (catRow['friendship_level'] as num?)?.toInt() ?? next.friendship;
    return CareState.fromMap(Map<String, dynamic>.from(row), friendship: friendship);
  }

  Future<int> _fetchFriendship(String catId) async {
    final client = _ref.read(supabaseClientProvider);
    final row = await client
        .from('cats')
        .select('friendship_level')
        .eq('id', catId)
        .maybeSingle();
    return (row?['friendship_level'] as num?)?.toInt() ?? 0;
  }
}

final careRepositoryProvider = Provider<CareRepository>((ref) {
  return CareRepository(ref);
});

/// Holds one cat's care state and exposes the feed/play actions. Optimistically
/// updates the UI, then reconciles with the persisted row; reverts on failure.
class CareController extends StateNotifier<AsyncValue<CareState>> {
  CareController(this._ref, this._catId) : super(const AsyncValue.loading());

  final Ref _ref;
  final String _catId;

  CareRepository get _repo => _ref.read(careRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.fetch(_catId));
  }

  Future<void> feed({int bondGain = 1, int happinessGain = 5}) =>
      _apply((c) => c.fed(bondGain: bondGain, happinessGain: happinessGain));

  Future<void> play() => _apply((c) => c.played());

  Future<void> _apply(CareState Function(CareState) transform) async {
    final current = state.valueOrNull ?? CareState.initial(_catId);
    final optimistic = transform(current);
    state = AsyncValue.data(optimistic);
    try {
      state = AsyncValue.data(await _repo.persist(optimistic));
    } catch (_) {
      // Roll back to the real stored state so the bars never lie.
      await load();
    }
  }
}

final careControllerProvider = StateNotifierProvider.autoDispose
    .family<CareController, AsyncValue<CareState>, String>((ref, catId) {
  return CareController(ref, catId)..load();
});
