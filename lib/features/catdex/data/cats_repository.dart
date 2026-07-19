import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/cat.dart';

/// Reads the player's caught cats. RLS scopes every query to the signed-in user,
/// so no explicit `profile_id` filter is needed here.
class CatsRepository {
  CatsRepository(this._ref);

  final Ref _ref;

  Future<List<Cat>> fetchAll() async {
    final client = _ref.read(supabaseClientProvider);
    final rows = await client
        .from('cats')
        .select('id, name, sprite_url, trait_id, generation_meta, '
            'geo_lat, geo_lng, discovered_at, cosmetic_collar')
        .order('discovered_at', ascending: false);
    return rows
        .map((row) => Cat.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Renames a caught cat. RLS scopes the update to the signed-in user's own
  /// rows, so no explicit `profile_id` filter is needed. The trimmed name is
  /// stored as-is; the caller enforces length/emptiness.
  Future<void> rename(String catId, String name) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('cats').update({'name': name}).eq('id', catId);
  }

  /// Equips (or clears, when null) a cat's cosmetic collar. RLS scopes the
  /// update to the signed-in user's own rows.
  Future<void> setCollar(String catId, String? collarId) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('cats')
        .update({'cosmetic_collar': collarId})
        .eq('id', catId);
  }

  /// Removes a caught cat. Used when the player taps "Retake photo" on the
  /// reveal to discard the companion that was just generated. RLS scopes the
  /// delete to the signed-in user's own rows.
  Future<void> delete(String catId) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('cats').delete().eq('id', catId);
  }
}

final catsRepositoryProvider = Provider<CatsRepository>((ref) {
  return CatsRepository(ref);
});

/// The player's CatDex. Auto-disposes so it re-fetches each time the tab is
/// opened; invalidate it after a successful catch to show the newcomer.
final catsProvider = FutureProvider.autoDispose<List<Cat>>((ref) async {
  return ref.read(catsRepositoryProvider).fetchAll();
});
