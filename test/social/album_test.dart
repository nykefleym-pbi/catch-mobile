import 'package:catch_mobile/features/social/data/album_repository.dart';
import 'package:catch_mobile/features/social/domain/photo_album.dart';
import 'package:catch_mobile/features/social/domain/safe_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlbumCat', () {
    test('parses a nested owner entry row and prefers nickname', () {
      final c = AlbumCat.fromEntryRow(const {
        'cat_id': 'c1',
        'caption': 'My best friend',
        'position': 2,
        'cats': {
          'name': 'Mittens',
          'nickname': 'Mimi',
          'sprite_url': 'https://x/y.png',
          'growth_stage': 'adult',
        },
      });
      expect(c.displayName, 'Mimi');
      expect(c.growthLabel, 'Adult');
      expect(c.caption, 'My best friend');
      expect(c.position, 2);
      expect(c.spriteUrl, 'https://x/y.png');
    });

    test('parses a flat RPC row and falls back name then gentle default', () {
      final c = AlbumCat.fromRpcRow(const {
        'cat_id': 'c2',
        'name': 'Mittens',
        'growth_stage': 'kitten',
        'caption': null,
        'sort_pos': 0,
      });
      expect(c.displayName, 'Mittens');
      expect(c.growthLabel, 'Kitten');

      final bare = AlbumCat.fromRpcRow(const {'cat_id': 'c3', 'sort_pos': 1});
      expect(bare.displayName, 'A cat');
      expect(bare.growthLabel, 'Cat');
    });

    test('carries no location field (privacy: albums never reveal place)', () {
      // Even if a caller slipped a location in, the model has nowhere to keep
      // it — the friend-read RPC deliberately omits it, and so does this model.
      final c = AlbumCat.fromRpcRow(const {
        'cat_id': 'c4',
        'name': 'Mittens',
        'sort_pos': 0,
        'location_label': 'Downtown',
      });
      expect(c.toString().contains('Downtown'), isFalse);
    });
  });

  group('Album', () {
    test('sorts embedded owner entries by position', () {
      final a = Album.fromOwnerRow(const {
        'id': 'a1',
        'title': 'Sunbeams',
        'is_shared': true,
        'album_entries': [
          {
            'cat_id': 'c2',
            'position': 1,
            'caption': null,
            'cats': {'name': 'Two'},
          },
          {
            'cat_id': 'c1',
            'position': 0,
            'caption': null,
            'cats': {'name': 'One'},
          },
        ],
      });
      expect(a.title, 'Sunbeams');
      expect(a.isShared, isTrue);
      expect(a.count, 2);
      expect(a.cats.first.catId, 'c1'); // position 0 comes first
      expect(a.cats.last.catId, 'c2');
    });

    test('groups flat RPC rows into albums preserving order', () {
      final albums = Album.fromRpcRows(const [
        {
          'album_id': 'a1',
          'album_title': 'Cozy',
          'cat_id': 'c1',
          'name': 'One',
          'sort_pos': 0,
        },
        {
          'album_id': 'a1',
          'album_title': 'Cozy',
          'cat_id': 'c2',
          'name': 'Two',
          'sort_pos': 1,
        },
        {
          'album_id': 'a2',
          'album_title': 'Naps',
          'cat_id': 'c3',
          'name': 'Three',
          'sort_pos': 0,
        },
      ]);
      expect(albums.length, 2);
      expect(albums.first.id, 'a1');
      expect(albums.first.title, 'Cozy');
      expect(albums.first.cats.length, 2);
      expect(albums.first.isShared, isTrue); // a shared album, by definition
      expect(albums.last.id, 'a2');
      expect(albums.last.cats.single.displayName, 'Three');
    });

    test('empty album is empty', () {
      final a = Album.fromOwnerRow(const {'id': 'a', 'is_shared': false});
      expect(a.count, 0);
      expect(a.title, 'My album'); // gentle default
    });
  });

  group('friendAlbums gating (kSocialLive)', () {
    test('the master switch is off in this build', () {
      expect(kSocialLive, isFalse);
    });

    test('returns empty with no network read while gated', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(albumRepositoryProvider);
      expect(await repo.friendAlbums('friend-1'), isEmpty);
    });
  });
}
