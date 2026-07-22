import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diary_repository.dart';
import '../domain/diary_entry.dart';

/// A cat's private diary — an owner-only timeline of little notes and moments.
/// Never a shared surface; minors' notes stay on-device (see DiaryRepository).
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key, required this.catId, required this.catName});

  final String catId;
  final String catName;

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(diaryRepositoryProvider).addNote(widget.catId, text);
      _controller.clear();
      ref.invalidate(catDiaryProvider(widget.catId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Couldn't save that note — please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(catDiaryProvider(widget.catId));
    return Scaffold(
      appBar: AppBar(title: Text('${widget.catName}\'s diary')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: entries.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Couldn\'t open the diary just now.',
                        textAlign: TextAlign.center),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_stories_outlined,
                                size: 48, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              'No entries yet — jot down a little memory of '
                              '${widget.catName}.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _DiaryTile(entry: list[i]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Add a little note…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _saving ? null : () => unawaited(_add()),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryTile extends StatelessWidget {
  const _DiaryTile({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = entry.createdAt.toLocal();
    final date = '${d.day}/${d.month}/${d.year}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.body != null && entry.body!.isNotEmpty)
            Text(entry.body!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                date,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (entry.locationLabel != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.place_outlined,
                    size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Text(
                  entry.locationLabel!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
