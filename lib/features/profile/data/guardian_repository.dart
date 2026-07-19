import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/guardian_profile.dart';

/// Aggregates the player's Guardian profile from their `profiles` row and their
/// caught `cats`. RLS scopes every read/write to the signed-in user.
class GuardianRepository {
  GuardianRepository(this._ref);

  final Ref _ref;

  Future<GuardianProfile> fetch() async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;

    final catRows = await client
        .from('cats')
        .select('friendship_level, geo_lat, geo_lng');
    final cats = (catRows as List).cast<Map<String, dynamic>>();
    final totalBond = cats.fold<int>(
      0,
      (sum, row) => sum + ((row['friendship_level'] as num?)?.toInt() ?? 0),
    );

    // Distinct fuzzed neighbourhoods (coords are already coarse ~1 km, 2 dp).
    final places = <String>{};
    for (final row in cats) {
      final lat = _toDouble(row['geo_lat']);
      final lng = _toDouble(row['geo_lng']);
      if (lat != null && lng != null) {
        places.add('${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}');
      }
    }

    String? displayName;
    if (userId != null) {
      final profile = await client
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      final raw = profile?['display_name'] as String?;
      displayName = (raw != null && raw.trim().isNotEmpty) ? raw.trim() : null;
    }

    return GuardianProfile(
      displayName: displayName,
      catsCount: cats.length,
      totalBond: totalBond,
      placesExplored: places.length,
    );
  }

  /// Sets (or clears, when blank) the player's Guardian name on their profile.
  Future<void> setDisplayName(String name) async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final trimmed = name.trim();
    await client
        .from('profiles')
        .update({'display_name': trimmed.isEmpty ? null : trimmed})
        .eq('id', userId);
  }
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

final guardianRepositoryProvider = Provider<GuardianRepository>((ref) {
  return GuardianRepository(ref);
});

/// The player's Guardian profile. Auto-disposes so it re-aggregates each time
/// the tab is opened; invalidate it after renaming to refresh.
final guardianProfileProvider =
    FutureProvider.autoDispose<GuardianProfile>((ref) async {
  return ref.read(guardianRepositoryProvider).fetch();
});
