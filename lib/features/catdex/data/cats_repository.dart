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
            'geo_lat, geo_lng, discovered_at')
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
}

final catsRepositoryProvider = Provider<CatsRepository>((ref) {
  return CatsRepository(ref);
});

/// The player's CatDex. Auto-disposes so it re-fetches each time the tab is
/// opened; invalidate it after a successful catch to show the newcomer.
final catsProvider = FutureProvider.autoDispose<List<Cat>>((ref) async {
  return ref.read(catsRepositoryProvider).fetchAll();
});
