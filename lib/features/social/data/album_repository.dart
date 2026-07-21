import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../domain/photo_album.dart';
import '../domain/safe_play.dart';

/// Shared photo albums (roadmap p3c). An album is a curated, captioned selection
/// of the owner's OWN cat sprites — never a camera image, never any location
/// (ADR 0001 / 08-ethics R6). Owner reads and writes flow through RLS
/// (`albums` / `album_entries` are owner-access); a friend's *shared* albums are
/// read through the guarded `list_friend_albums` RPC (migration 0015).
///
/// The friend-viewing path is held behind [kSocialLive]: while off it returns an
/// empty list without any network call, so no live user-to-user read happens
/// until the master switch flips. Owner-side management touches only the owner's
/// own rows and is safe regardless, but the UI keeps it behind the same gate for
/// an honest, consistent "coming soon" surface.
class AlbumRepository {
  AlbumRepository(this._ref);

  final Ref _ref;

  String? get _uid => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  static const _embed =
      'id, title, is_shared, album_entries(cat_id, caption, position, '
      'cats(name, nickname, sprite_url, growth_stage))';

  /// The player's own albums, newest first, with their entries embedded.
  Future<List<Album>> myAlbums() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .from('albums')
        .select(_embed)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((r) => Album.fromOwnerRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Creates an empty album and returns its id (null if unauthenticated).
  Future<String?> create(String title) async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _ref
        .read(supabaseClientProvider)
        .from('albums')
        .insert({'owner_id': uid, 'title': _cleanTitle(title)})
        .select('id')
        .single();
    return row['id'] as String?;
  }

  Future<void> rename(String albumId, String title) => _ref
      .read(supabaseClientProvider)
      .from('albums')
      .update({'title': _cleanTitle(title), 'updated_at': _now()}).eq(
          'id', albumId);

  Future<void> setShared(String albumId, {required bool shared}) => _ref
      .read(supabaseClientProvider)
      .from('albums')
      .update({'is_shared': shared, 'updated_at': _now()}).eq('id', albumId);

  Future<void> deleteAlbum(String albumId) => _ref
      .read(supabaseClientProvider)
      .from('albums')
      .delete()
      .eq('id', albumId);

  /// Adds one of the owner's cats to an album at the end of the current order.
  /// Idempotent on the (album, cat) pair thanks to the composite primary key.
  Future<void> addCat(String albumId, String catId,
      {String? caption, required int position}) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('album_entries').upsert({
      'album_id': albumId,
      'cat_id': catId,
      'position': position,
      'caption': _cleanCaption(caption),
    });
    await client
        .from('albums')
        .update({'updated_at': _now()}).eq('id', albumId);
  }

  Future<void> removeCat(String albumId, String catId) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('album_entries')
        .delete()
        .eq('album_id', albumId)
        .eq('cat_id', catId);
    await client
        .from('albums')
        .update({'updated_at': _now()}).eq('id', albumId);
  }

  Future<void> setCaption(String albumId, String catId, String? caption) => _ref
      .read(supabaseClientProvider)
      .from('album_entries')
      .update({'caption': _cleanCaption(caption)})
      .eq('album_id', albumId)
      .eq('cat_id', catId);

  /// A friend's shared albums, via the guarded `list_friend_albums` RPC. Gated
  /// by [kSocialLive]: empty (no network) while live social is off.
  Future<List<Album>> friendAlbums(String friendId) async {
    if (!kSocialLive) return const [];
    final rows = await _ref
        .read(supabaseClientProvider)
        .rpc('list_friend_albums', params: {'p_friend': friendId});
    return Album.fromRpcRows(
      (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList(),
    );
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static String _cleanTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return 'My album';
    return t.length > 60 ? t.substring(0, 60) : t;
  }

  static String? _cleanCaption(String? caption) {
    final c = caption?.trim();
    if (c == null || c.isEmpty) return null;
    return c.length > 140 ? c.substring(0, 140) : c;
  }
}

final albumRepositoryProvider =
    Provider<AlbumRepository>((ref) => AlbumRepository(ref));

/// The player's own albums. Auto-disposes so the screen refreshes on open;
/// invalidate after any mutation.
final myAlbumsProvider = FutureProvider.autoDispose<List<Album>>(
  (ref) => ref.read(albumRepositoryProvider).myAlbums(),
);

/// A friend's shared albums, keyed by friend id. Empty while [kSocialLive] is
/// off (the repository short-circuits without a network call).
final friendAlbumsProvider =
    FutureProvider.autoDispose.family<List<Album>, String>(
  (ref, friendId) => ref.read(albumRepositoryProvider).friendAlbums(friendId),
);
