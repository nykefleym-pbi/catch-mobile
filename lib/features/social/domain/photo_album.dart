import 'package:flutter/foundation.dart';

/// One cat sitting in an album — the owner's own companion, with an optional
/// caption. Carries only safe, cosmetic fields: there is **no location** and no
/// camera image (real photos are deleted after generation, ADR 0001), so an
/// album entry can never reveal where a real cat was met.
@immutable
class AlbumCat {
  const AlbumCat({
    required this.catId,
    required this.name,
    this.nickname,
    this.spriteUrl,
    this.growthStage,
    this.caption,
    this.position = 0,
  });

  final String catId;
  final String name;
  final String? nickname;
  final String? spriteUrl;
  final String? growthStage;
  final String? caption;
  final int position;

  /// Nickname first, then name, then a gentle default — never blank.
  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final n = name.trim();
    return n.isNotEmpty ? n : 'A cat';
  }

  String get growthLabel => switch (growthStage) {
        'kitten' => 'Kitten',
        'young' => 'Young',
        'adult' => 'Adult',
        'senior' => 'Senior',
        _ => 'Cat',
      };

  /// From a nested `album_entries` row embedded under an owner's album read:
  /// `{cat_id, caption, position, cats: {name, nickname, sprite_url, growth_stage}}`.
  factory AlbumCat.fromEntryRow(Map<String, dynamic> row) {
    final cat = row['cats'];
    final catMap = cat is Map ? Map<String, dynamic>.from(cat) : const {};
    return AlbumCat(
      catId: row['cat_id'] as String,
      name: (catMap['name'] as String?) ?? '',
      nickname: catMap['nickname'] as String?,
      spriteUrl: catMap['sprite_url'] as String?,
      growthStage: catMap['growth_stage'] as String?,
      caption: row['caption'] as String?,
      position: (row['position'] as int?) ?? 0,
    );
  }

  /// From a flat `list_friend_albums` RPC row (the friend-viewing path).
  factory AlbumCat.fromRpcRow(Map<String, dynamic> row) => AlbumCat(
        catId: row['cat_id'] as String,
        name: (row['name'] as String?) ?? '',
        nickname: row['nickname'] as String?,
        spriteUrl: row['sprite_url'] as String?,
        growthStage: row['growth_stage'] as String?,
        caption: row['caption'] as String?,
        position: (row['sort_pos'] as int?) ?? 0,
      );
}

/// A curated collection of the owner's own cats. Private until [isShared] is
/// switched on; accepted friends then read it through the guarded
/// `list_friend_albums` RPC (migration 0015).
@immutable
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.isShared,
    this.cats = const [],
  });

  final String id;
  final String title;
  final bool isShared;
  final List<AlbumCat> cats;

  int get count => cats.length;

  Album copyWith({String? title, bool? isShared, List<AlbumCat>? cats}) => Album(
        id: id,
        title: title ?? this.title,
        isShared: isShared ?? this.isShared,
        cats: cats ?? this.cats,
      );

  /// From an owner's `albums` read that embeds `album_entries(..., cats(...))`.
  factory Album.fromOwnerRow(Map<String, dynamic> row) {
    final rawEntries = row['album_entries'];
    final entries = <AlbumCat>[
      if (rawEntries is List)
        for (final e in rawEntries)
          AlbumCat.fromEntryRow(Map<String, dynamic>.from(e as Map)),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return Album(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? 'My album',
      isShared: row['is_shared'] == true,
      cats: entries,
    );
  }

  /// Groups flat `list_friend_albums` RPC rows (album_id repeated per entry)
  /// into albums, preserving the server's ordering.
  static List<Album> fromRpcRows(List<Map<String, dynamic>> rows) {
    final order = <String>[];
    final byId = <String, List<AlbumCat>>{};
    final titles = <String, String>{};
    for (final row in rows) {
      final id = row['album_id'] as String;
      if (!byId.containsKey(id)) {
        order.add(id);
        byId[id] = [];
        titles[id] = (row['album_title'] as String?) ?? 'Album';
      }
      byId[id]!.add(AlbumCat.fromRpcRow(row));
    }
    return [
      for (final id in order)
        Album(id: id, title: titles[id]!, isShared: true, cats: byId[id]!),
    ];
  }
}
