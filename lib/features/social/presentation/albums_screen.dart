import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../catdex/data/cats_repository.dart';
import '../../catdex/domain/cat.dart';
import '../../safety/data/age_gate.dart';
import '../data/album_repository.dart';
import '../domain/photo_album.dart';
import '../domain/safe_play.dart';

/// Shared photo albums (roadmap p3c) — a cozy, curated collection of your own
/// companions to share with an accepted friend. There is no camera image here
/// and never any location: an album holds only the cat sprites you choose, with
/// the captions you write (ADR 0001 / 08-ethics R6). Sharing is friends-only and
/// adult-only (mirroring the showcase), and the whole surface is held behind
/// [kSocialLive] — while off, it shows an honest gated state and never a
/// simulated feed.
class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo albums')),
      body: const SafeArea(
        top: false,
        child: kSocialLive ? _AlbumsList() : _AlbumsGatedState(),
      ),
    );
  }
}

class _AlbumsList extends ConsumerWidget {
  const _AlbumsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(myAlbumsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAlbum(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New album'),
      ),
      body: albums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _CenteredMessage(
          "We couldn't load your albums just now. Please try again.",
        ),
        data: (list) {
          if (list.isEmpty) return const _EmptyAlbums();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _AlbumCard(album: list[i]),
          );
        },
      ),
    );
  }

  Future<void> _createAlbum(BuildContext context, WidgetRef ref) async {
    final title = await _promptText(
      context,
      title: 'New album',
      label: 'Album name',
      initial: '',
      action: 'Create',
    );
    if (title == null) return;
    await ref.read(albumRepositoryProvider).create(title);
    ref.invalidate(myAlbumsProvider);
  }
}

class _AlbumCard extends ConsumerWidget {
  const _AlbumCard({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AlbumDetailScreen(albumId: album.id),
          ),
        ),
        child: Row(
          children: [
            _AlbumThumb(album: album),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${album.count} ${album.count == 1 ? 'cat' : 'cats'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (album.isShared)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.sage.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                ),
                child: Text('Shared',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _AlbumThumb extends StatelessWidget {
  const _AlbumThumb({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = album.cats.isEmpty ? null : album.cats.first.spriteUrl;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusChip),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Icon(Icons.photo_library_outlined,
              color: theme.colorScheme.primary)
          : Image.network(
              url,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, __, ___) => Icon(Icons.photo_library_outlined,
                  color: theme.colorScheme.primary),
            ),
    );
  }
}

/// The editor for one album: rename, share toggle (adult-only), add/remove the
/// owner's own cats, and caption them. All writes touch only the owner's rows.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final String albumId;

  Album? _find(List<Album>? list) {
    if (list == null) return null;
    for (final a in list) {
      if (a.id == albumId) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(myAlbumsProvider);
    final album = _find(albums.valueOrNull);
    return Scaffold(
      appBar: AppBar(
        title: Text(album?.title ?? 'Album'),
        actions: [
          if (album != null)
            IconButton(
              icon: const Icon(Icons.drive_file_rename_outline),
              tooltip: 'Rename',
              onPressed: () => _rename(context, ref, album),
            ),
          if (album != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete album',
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: albums.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _CenteredMessage(
            "We couldn't open this album just now.",
          ),
          data: (_) => album == null
              ? const _CenteredMessage('This album is no longer here.')
              : _AlbumBody(album: album),
        ),
      ),
      floatingActionButton: album == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addCats(context, ref, album),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add cats'),
            ),
    );
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, Album album) async {
    final title = await _promptText(
      context,
      title: 'Rename album',
      label: 'Album name',
      initial: album.title,
      action: 'Save',
    );
    if (title == null) return;
    await ref.read(albumRepositoryProvider).rename(album.id, title);
    ref.invalidate(myAlbumsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this album?'),
        content: const Text(
          'The album and its captions are removed. Your cats are safe — only '
          'the album is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(albumRepositoryProvider).deleteAlbum(albumId);
    ref.invalidate(myAlbumsProvider);
    navigator.pop();
  }

  Future<void> _addCats(
      BuildContext context, WidgetRef ref, Album album) async {
    final inAlbum = album.cats.map((c) => c.catId).toSet();
    final all = await ref.read(catsProvider.future);
    final available = all.where((c) => !inAlbum.contains(c.id)).toList();
    if (!context.mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every cat is already in this album 🐾')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CatPickerSheet(cats: available),
    );
    if (picked == null || picked.isEmpty) return;
    final repo = ref.read(albumRepositoryProvider);
    var pos = album.count;
    for (final id in picked) {
      await repo.addCat(album.id, id, position: pos);
      pos++;
    }
    ref.invalidate(myAlbumsProvider);
  }
}

class _AlbumBody extends ConsumerWidget {
  const _AlbumBody({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(socialCapabilitiesProvider);
    final canShare = caps.canShowcaseToFriends;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _ShareCard(
          album: album,
          enabled: canShare,
          onChanged: canShare
              ? (v) async {
                  await ref
                      .read(albumRepositoryProvider)
                      .setShared(album.id, shared: v);
                  ref.invalidate(myAlbumsProvider);
                }
              : null,
        ),
        const SizedBox(height: 20),
        if (album.cats.isEmpty)
          const _CenteredMessage(
            'This album is empty. Tap “Add cats” to bring your companions in.',
          )
        else
          for (final cat in album.cats)
            _EntryRow(
              cat: cat,
              onCaption: () => _editCaption(context, ref, cat),
              onRemove: () async {
                await ref
                    .read(albumRepositoryProvider)
                    .removeCat(album.id, cat.catId);
                ref.invalidate(myAlbumsProvider);
              },
            ),
      ],
    );
  }

  Future<void> _editCaption(
      BuildContext context, WidgetRef ref, AlbumCat cat) async {
    final caption = await _promptText(
      context,
      title: 'Caption',
      label: 'A little note',
      initial: cat.caption ?? '',
      action: 'Save',
      allowEmpty: true,
      maxLength: 140,
    );
    if (caption == null) return;
    await ref
        .read(albumRepositoryProvider)
        .setCaption(album.id, cat.catId, caption.isEmpty ? null : caption);
    ref.invalidate(myAlbumsProvider);
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.album,
    required this.enabled,
    required this.onChanged,
  });

  final Album album;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: SwitchListTile(
        value: enabled && album.isShared,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        title: const Text('Share with friends'),
        subtitle: Text(
          enabled
              ? 'Accepted friends can page through this album. Never public, and '
                  'never any location — just the cats you chose.'
              : 'Sharing albums stays off for under-18s, for safety. You can '
                  'still make albums to enjoy yourself.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.cat,
    required this.onCaption,
    required this.onRemove,
  });

  final AlbumCat cat;
  final VoidCallback onCaption;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusChip),
            ),
            clipBehavior: Clip.antiAlias,
            child: cat.spriteUrl == null
                ? Icon(Icons.pets, color: theme.colorScheme.primary)
                : Image.network(
                    cat.spriteUrl!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.pets, color: theme.colorScheme.primary),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.displayName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onCaption,
                  child: Text(
                    cat.caption?.isNotEmpty == true
                        ? cat.caption!
                        : 'Add a caption…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: cat.caption?.isNotEmpty == true
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Remove from album',
            onPressed: () => unawaited(onRemove()),
          ),
        ],
      ),
    );
  }
}

/// A multi-select sheet of the owner's cats not yet in the album.
class _CatPickerSheet extends StatefulWidget {
  const _CatPickerSheet({required this.cats});

  final List<Cat> cats;

  @override
  State<_CatPickerSheet> createState() => _CatPickerSheetState();
}

class _CatPickerSheetState extends State<_CatPickerSheet> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Text('Add cats',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.cats.length,
              itemBuilder: (_, i) {
                final cat = widget.cats[i];
                final on = _selected.contains(cat.id);
                return CheckboxListTile(
                  value: on,
                  onChanged: (_) => setState(() {
                    if (on) {
                      _selected.remove(cat.id);
                    } else {
                      _selected.add(cat.id);
                    }
                  }),
                  secondary: SizedBox(
                    width: 44,
                    height: 44,
                    child: cat.spriteUrl == null
                        ? Icon(Icons.pets, color: theme.colorScheme.primary)
                        : Image.network(cat.spriteUrl!,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => Icon(Icons.pets,
                                color: theme.colorScheme.primary)),
                  ),
                  title: Text(cat.name),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_selected),
                child: Text('Add ${_selected.length}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small reusable text prompt. Returns the trimmed value, or null if cancelled.
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
  required String action,
  bool allowEmpty = false,
  int maxLength = 60,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: maxLength,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty && !allowEmpty) return;
            Navigator.of(ctx).pop(text);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Read-only viewing of an accepted friend's *shared* albums (roadmap p3c). The
/// albums come from the guarded `list_friend_albums` RPC (migration 0015) — only
/// safe cat fields, never any location. Held behind [kSocialLive]: while off it
/// shows the same honest gated state and never touches the network.
class FriendAlbumsScreen extends ConsumerWidget {
  const FriendAlbumsScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  final String friendId;
  final String friendName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text("$friendName's albums")),
      body: SafeArea(
        top: false,
        child: kSocialLive ? _live(ref) : const _AlbumsGatedState(),
      ),
    );
  }

  Widget _live(WidgetRef ref) {
    final albums = ref.watch(friendAlbumsProvider(friendId));
    return albums.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _CenteredMessage(
        "We couldn't open these albums right now. Please try again.",
      ),
      data: (list) => list.isEmpty
          ? _CenteredMessage("$friendName hasn't shared any albums yet.")
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: list.length,
              itemBuilder: (_, i) => _FriendAlbumSection(album: list[i]),
            ),
    );
  }
}

class _FriendAlbumSection extends StatelessWidget {
  const _FriendAlbumSection({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(album.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: album.cats.length,
          itemBuilder: (_, i) => _FriendAlbumTile(cat: album.cats[i]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _FriendAlbumTile extends StatelessWidget {
  const _FriendAlbumTile({required this.cat});

  final AlbumCat cat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: cat.spriteUrl == null
                  ? Icon(Icons.pets, size: 44, color: theme.colorScheme.primary)
                  : Image.network(
                      cat.spriteUrl!,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, __, ___) => Icon(Icons.pets,
                          size: 44, color: theme.colorScheme.primary),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(cat.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (cat.caption?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(cat.caption!,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _EmptyAlbums extends StatelessWidget {
  const _EmptyAlbums();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No albums yet',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Make a cozy album of your companions — choose the cats, add a few '
              'kind words, and share it with a friend when you\'re ready.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: child,
    );
  }
}

/// Shown while [kSocialLive] is off — honest about what albums will be and the
/// safeguards, never a simulated feed.
class _AlbumsGatedState extends StatelessWidget {
  const _AlbumsGatedState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.sage.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: AppTheme.cardShadow(theme.brightness),
          ),
          child: Column(
            children: [
              const Text('📷', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Shared albums are coming',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Make a cozy album of your companions to share with a friend — '
                'only the cats you choose, only with friends you\'ve accepted, '
                'and moderated. Never a public feed, and no location is ever '
                'shared. We\'ll switch it on once we can host it safely.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
