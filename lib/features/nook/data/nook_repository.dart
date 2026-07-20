import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/decor.dart';

/// Reads and writes a cat's decorated nook layout (`cats.nook_layout`). RLS
/// scopes every query to the signed-in user's own rows.
class NookRepository {
  NookRepository(this._ref);

  final Ref _ref;

  Future<List<PlacedDecor>> fetch(String catId) async {
    final client = _ref.read(supabaseClientProvider);
    final row = await client
        .from('cats')
        .select('nook_layout')
        .eq('id', catId)
        .maybeSingle();
    final raw = row?['nook_layout'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => PlacedDecor.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.itemId.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<void> save(String catId, List<PlacedDecor> layout) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('cats')
        .update({'nook_layout': layout.map((p) => p.toJson()).toList()})
        .eq('id', catId);
  }
}

final nookRepositoryProvider = Provider<NookRepository>((ref) {
  return NookRepository(ref);
});
