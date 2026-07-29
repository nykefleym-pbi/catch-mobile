import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../data/supabase/supabase_providers.dart';
import '../../safety/data/age_gate.dart';
import '../domain/care_state.dart';

/// Reads and writes a cat's [CareState]. RLS scopes every query to the signed-in
/// user, so no explicit `profile_id` filter is needed on reads.
class CareRepository {
  CareRepository(this._ref);

  final Ref _ref;

  static const _columns =
      'cat_id, hunger, happiness, hygiene, sleep, play, mood, last_updated';

  Future<CareState> fetch(String catId) async {
    final client = _ref.read(supabaseClientProvider);
    final row = await client
        .from('care_state')
        .select(_columns)
        .eq('cat_id', catId)
        .maybeSingle();
    final meta = await _fetchCatMeta(catId);
    if (row == null) {
      return CareState.initial(catId,
          friendship: meta.friendship, traitId: meta.traitId);
    }
    return CareState.fromMap(Map<String, dynamic>.from(row),
        friendship: meta.friendship, traitId: meta.traitId);
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
        .select('friendship_level, trait_id')
        .single();
    final friendship =
        (catRow['friendship_level'] as num?)?.toInt() ?? next.friendship;
    return CareState.fromMap(Map<String, dynamic>.from(row),
        friendship: friendship, traitId: catRow['trait_id'] as String?);
  }

  /// A gentle, best-effort snapshot of every cat's name + single lowest need,
  /// for the while-away care reminders. One query embeds each cat's `care_state`
  /// row; the drift-since-last-cared value is computed client-side via
  /// [CareState], so the copy can name the actual need. RLS scopes the read to
  /// the signed-in user. Returns records (not a reminder type) so the care layer
  /// stays independent of the notifications feature.
  Future<List<({String name, String? lowNeed})>> fetchCatNeeds(
      {int threshold = 45}) async {
    final client = _ref.read(supabaseClientProvider);
    final rows = await client.from('cats').select(
        'name, trait_id, care_state(hunger, happiness, hygiene, sleep, play, '
        'mood, last_updated)');
    final out = <({String name, String? lowNeed})>[];
    for (final row in rows) {
      final name = (row['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final raw = row['care_state'];
      final Map<String, dynamic>? careMap = raw is Map
          ? Map<String, dynamic>.from(raw)
          : (raw is List && raw.isNotEmpty
              ? Map<String, dynamic>.from(raw.first as Map)
              : null);
      final traitId = row['trait_id'] as String?;
      final care = careMap == null
          ? CareState.initial('', traitId: traitId)
          : CareState.fromMap({...careMap, 'cat_id': ''}, traitId: traitId);
      out.add((name: name, lowNeed: care.lowestNeed(threshold: threshold)));
    }
    return out;
  }

  Future<({int friendship, String? traitId})> _fetchCatMeta(
      String catId) async {
    final client = _ref.read(supabaseClientProvider);
    final row = await client
        .from('cats')
        .select('friendship_level, trait_id')
        .eq('id', catId)
        .maybeSingle();
    return (
      friendship: (row?['friendship_level'] as num?)?.toInt() ?? 0,
      traitId: row?['trait_id'] as String?,
    );
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

  Future<void> feed({int bondGain = 1, int happinessGain = 5}) => _apply(
        (c) => c.fed(bondGain: bondGain, happinessGain: happinessGain),
        AnalyticsEventName.careFed,
      );

  Future<void> play() => _apply((c) => c.played(), AnalyticsEventName.carePlayed);

  Future<void> groom() =>
      _apply((c) => c.groomed(), AnalyticsEventName.careGroomed);

  /// Commit a hands-on feeding session: hunger reached [fullness], bond earned.
  Future<void> commitFeed(int fullness, int bondGain) => _apply(
        (c) => c.afterFeedSession(fullness, bondGain),
        AnalyticsEventName.careFed,
      );

  /// Commit a play session: happiness reached [fullness], bond earned.
  Future<void> commitPlay(int fullness, int bondGain) => _apply(
        (c) => c.afterPlaySession(fullness, bondGain),
        AnalyticsEventName.carePlayed,
      );

  /// Commit a grooming session: hygiene reached [fullness], bond earned.
  Future<void> commitGroom(int fullness, int bondGain) => _apply(
        (c) => c.afterGroomSession(fullness, bondGain),
        AnalyticsEventName.careGroomed,
      );

  Future<void> _apply(
    CareState Function(CareState) transform,
    AnalyticsEventName event,
  ) async {
    final current = state.valueOrNull ?? CareState.initial(_catId);
    final optimistic = transform(current);
    state = AsyncValue.data(optimistic);
    try {
      state = AsyncValue.data(await _repo.persist(optimistic));
      // Count the successful care action. No cat id, no bond value — just that a
      // care action of this kind happened; minors send the bare event only.
      _ref.read(analyticsProvider).log(
            event,
            reducedData: _ref.read(ageBracketProvider).isMinor,
          );
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
