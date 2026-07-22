import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../academy/domain/care_lesson.dart';
import '../../academy/domain/care_moment.dart';
import '../../care/data/care_repository.dart';
import '../../care/domain/care_state.dart';
import '../../care/domain/treat.dart';
import '../../care/presentation/spa_screen.dart';
import '../../nook/presentation/nook_screen.dart';
import '../../pvp/domain/cat_stats.dart';
import '../../pvp/presentation/practice_ground_screen.dart';
import '../../wardrobe/domain/collar.dart';
import '../../wardrobe/presentation/collar_sheet.dart';
import '../data/cats_repository.dart';
import '../domain/cat.dart';
import 'cat_idle_sprite.dart';

/// A single companion's page, styled from the "Cat-ch Mobile UI" design: a warm
/// hero with the (reactive) pixel sprite, an overlapping rounded sheet with the
/// cat's story, gentle gradient need-meters, a friendship hearts row, and the
/// care controls — feed + play — that grow a permanent bond with juicy feedback.
///
/// The [Cat] is passed via `GoRouter` `extra` when opened from the CatDex; a
/// deep link without it falls back to a gentle "open from your CatDex" prompt.
class CatDetailScreen extends StatelessWidget {
  const CatDetailScreen({required this.catId, this.cat, super.key});

  final String catId;
  final Cat? cat;

  @override
  Widget build(BuildContext context) {
    final cat = this.cat;
    if (cat == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Open this cat from your CatDex to see its page.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(body: _CompanionBody(catId: catId, cat: cat));
  }
}

class _CompanionBody extends ConsumerStatefulWidget {
  const _CompanionBody({required this.catId, required this.cat});

  final String catId;
  final Cat cat;

  @override
  ConsumerState<_CompanionBody> createState() => _CompanionBodyState();
}

class _CompanionBodyState extends ConsumerState<_CompanionBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  final List<_FloaterSpec> _floaters = [];
  final math.Random _random = math.Random();
  int _floaterSeq = 0;

  /// The cat's name, held locally so an in-place rename updates this page
  /// immediately (the [Cat] arrives immutable via router `extra`). Starts from
  /// the passed-in cat and is kept in sync across care messages + sharing.
  late String _name;
  bool _sharing = false;

  /// Which sheet tab is showing: 0 = Story (care), 1 = Details (card back).
  int _tab = 0;

  /// The equipped cosmetic collar id, held locally so equipping updates this
  /// page immediately (the [Cat] arrives immutable via router `extra`).
  String? _collarId;

  @override
  void initState() {
    super.initState();
    _name = widget.cat.name;
    _collarId = widget.cat.collarId;
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _openTreatPicker() async {
    final treat = await showModalBottomSheet<Treat>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _TreatSheet(),
    );
    if (treat == null) return;
    await _feed(treat);
  }

  Future<void> _feed(Treat treat) {
    // The 'foodie' trait "gains extra affection from feeding" (0002 seed).
    final foodie = widget.cat.traitId == 'foodie';
    final bond = treat.bond + (foodie ? 1 : 0);
    return _runCare(
      floater: treat.emoji,
      action: () => ref.read(careControllerProvider(widget.catId).notifier).feed(
            bondGain: bond,
            happinessGain: treat.happiness,
          ),
      message: foodie
          ? '$_name devoured the ${treat.label}! ${treat.emoji}'
          : '$_name enjoyed ${treat.label} ${treat.emoji}',
    );
  }

  Future<void> _play() => _runCare(
        floater: '🧶',
        action: () =>
            ref.read(careControllerProvider(widget.catId).notifier).play(),
        message: '$_name had fun 🧶',
      );

  /// Opens the tactile "Spa day" grooming screen. It persists a gentle groom
  /// (hygiene + a little bond) on the first pampering, and shares this cat's
  /// care provider, so the meters here update when we return.
  void _openSpa() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SpaScreen(
          catId: widget.catId,
          name: _name,
          spriteUrl: widget.cat.spriteUrl,
        ),
      ),
    );
  }

  /// Opens this cat's decorated nook (home decoration).
  void _openNook() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NookScreen(
          catId: widget.catId,
          name: _name,
          spriteUrl: widget.cat.spriteUrl,
        ),
      ),
    );
  }

  /// Opens the wardrobe to pick a cosmetic collar. Collars unlock with this
  /// cat's bond, so we pass the current bond level in. Persists optimistically
  /// and refreshes the CatDex grid so the newcomer shows there too.
  Future<void> _openWardrobe() async {
    final friendship =
        ref.read(careControllerProvider(widget.catId)).valueOrNull?.friendship ??
            0;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => CollarSheet(
        bondIndex: Bond.levelIndexFor(friendship),
        equippedId: _collarId,
      ),
    );
    if (result == null) return; // dismissed
    final newId = result.isEmpty ? null : result;
    if (newId == _collarId) return;

    final previous = _collarId;
    setState(() => _collarId = newId); // optimistic
    try {
      await ref.read(catsRepositoryProvider).setCollar(widget.catId, newId);
      if (!mounted) return;
      ref.invalidate(catsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _collarId = previous); // roll back
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't save the collar — try again.")),
        );
    }
  }

  /// Shared care flow: haptic + sprite bounce + floating emoji, run the action,
  /// then a snackbar — celebrating a bond level-up when one happens.
  Future<void> _runCare({
    required String floater,
    required Future<void> Function() action,
    required String message,
  }) async {
    final provider = careControllerProvider(widget.catId);
    final before = ref.read(provider).valueOrNull?.friendship ?? 0;

    unawaited(HapticFeedback.lightImpact());
    unawaited(_bounce.forward(from: 0));
    _spawnFloater(floater);

    await action();
    if (!mounted) return;

    final after = ref.read(provider).valueOrNull?.friendship ?? before;
    final leveledUp = Bond.levelIndexFor(after) > Bond.levelIndexFor(before);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (leveledUp) {
      _spawnFloater('💛');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'You and $_name are now ${Bond.labelFor(after)}! 💛',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _spawnFloater(String emoji) {
    final id = _floaterSeq++;
    final dx = (_random.nextDouble() * 64) - 32;
    setState(() => _floaters.add(_FloaterSpec(id: id, emoji: emoji, dx: dx)));
  }

  void _removeFloater(int id) {
    if (!mounted) return;
    setState(() => _floaters.removeWhere((f) => f.id == id));
  }

  /// Opens a gentle rename dialog. On save, persists to Supabase, updates this
  /// page in place, and invalidates the CatDex so the grid reflects the new
  /// name. Failures leave the old name and surface a friendly retry prompt.
  Future<void> _openRename() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 24,
            decoration: const InputDecoration(
              hintText: 'Give your companion a name',
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              style: FilledButton.styleFrom(
                textStyle: theme.textTheme.labelLarge,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final trimmed = newName?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == _name) return;

    final previous = _name;
    setState(() => _name = trimmed); // optimistic
    try {
      await ref.read(catsRepositoryProvider).rename(widget.catId, trimmed);
      if (!mounted) return;
      ref.invalidate(catsProvider); // refresh the grid
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Renamed to $trimmed'),
            duration: const Duration(seconds: 1),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _name = previous); // roll back
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't rename — please try again.")),
        );
    }
  }

  /// Shares the companion to other apps — the sprite image plus a short story
  /// line. Downloading the sprite can fail (offline, etc.); we fall back to a
  /// text-only share so the button always does something useful.
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final trait = widget.cat.traitLabel;
    final blurb = widget.cat.blurb;
    final text = [
      'Meet $_name${trait != null ? ', my $trait companion' : ''} '
          'in Cat-ch! 🐾',
      if (blurb != null) blurb,
    ].join('\n');

    try {
      final bytes = await _downloadSprite(widget.cat.spriteUrl);
      if (!mounted) return;
      if (bytes != null) {
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: '$_name.png')],
          text: text,
        );
      } else {
        await Share.share(text);
      }
    } catch (_) {
      // Sharing can throw if the sheet is dismissed oddly; ignore silently.
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<Uint8List?> _downloadSprite(String? url) async {
    if (url == null) return null;
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    final care = ref.watch(careControllerProvider(widget.catId));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hero(cat, care.valueOrNull),
          Transform.translate(
            offset: const Offset(0, -28),
            child: _sheet(cat, care),
          ),
        ],
      ),
    );
  }

  // --- Hero: gradient panel + reactive sprite + back + mood badge -----------
  Widget _hero(Cat cat, CareState? care) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final collar = collarById(_collarId);
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 300 + topPad,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isLight
                      ? const [Color(0xFFFBE3CD), Color(0xFFF7D9BC)]
                      : const [Color(0xFF3C332B), Color(0xFF2B2420)],
                ),
              ),
            ),
          ),
          // Reactive sprite with floaters.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: topPad, bottom: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (collar != null)
                    IgnorePointer(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              collar.color.withValues(alpha: 0.32),
                              collar.color.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  AnimatedBuilder(
                    animation: _bounce,
                    builder: (context, child) {
                      final scale = 1 + 0.12 * math.sin(math.pi * _bounce.value);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: _HeroSprite(cat: cat),
                  ),
                  for (final f in _floaters)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(
                        child: Transform.translate(
                          offset: Offset(f.dx, 0),
                          child: _Floater(
                            key: ValueKey(f.id),
                            emoji: f.emoji,
                            onDone: () => _removeFloater(f.id),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: topPad + 12,
            left: 16,
            child: _RoundIconButton(
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: topPad + 12,
            right: 16,
            child: _RoundIconButton(
              icon: Icons.ios_share,
              onTap: _sharing ? null : _share,
            ),
          ),
          if (care != null)
            Positioned(
              right: 24,
              bottom: 44,
              child: _MoodBadge(mood: _titleCase(care.currentMood)),
            ),
        ],
      ),
    );
  }

  // --- Sheet: name, story, meters, bond, actions ---------------------------
  Widget _sheet(Cat cat, AsyncValue<CareState> care) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(_name,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              _PencilButton(onTap: _openRename),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (cat.traitLabel != null) _TraitChip(label: cat.traitLabel!),
              _CollarChip(
                collar: collarById(_collarId),
                onTap: _openWardrobe,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SegTabs(index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 18),
          if (_tab == 0)
            ..._storyChildren(cat, care)
          else
            _DetailsBody(
              cat: cat,
              friendship: care.valueOrNull?.friendship ?? 0,
              care: care.valueOrNull,
              onOpenNook: _openNook,
            ),
        ],
      ),
    );
  }

  /// The Story tab: the cat's backstory, where/when you met, then the live
  /// care body (meters, bond, feed + play).
  List<Widget> _storyChildren(Cat cat, AsyncValue<CareState> care) {
    final theme = Theme.of(context);
    return [
      Text(
        cat.story,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _metaLine(cat),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 20),
      care.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => SizedBox(
          height: 160,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Couldn't load care status."),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(careControllerProvider(widget.catId).notifier)
                      .load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: _careBody,
      ),
    ];
  }

  /// A gentle, contextual welfare tip — surfaces the Academy lesson that speaks
  /// to whatever need is currently low, right where the player is caring. Shows
  /// nothing when every need is healthy (never nags).
  Widget _careTip(CareState state) {
    final id = lessonForCareMoment(
      hunger: state.currentHunger,
      happiness: state.currentHappiness,
      hygiene: state.currentHygiene,
      sleep: state.currentSleep,
      play: state.currentPlay,
    );
    final CareLesson? lesson = id == null ? null : careLessonById(id);
    if (lesson == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Care tip · ${lesson.title}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lesson.tips.first,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _careBody(CareState state) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mood: ${_titleCase(state.currentMood)} · last cared for '
          '${state.lastCaredLabel}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _Meter(
          label: 'Hunger',
          status: _hungerStatus(state.currentHunger),
          value: state.currentHunger / 100,
          gradient: const [AppTheme.apricot, AppTheme.terracotta],
        ),
        const SizedBox(height: 14),
        _Meter(
          label: 'Happiness',
          status: _happyStatus(state.currentHappiness),
          value: state.currentHappiness / 100,
          gradient: const [AppTheme.sage, Color(0xFF8FB287)],
        ),
        const SizedBox(height: 14),
        _Meter(
          label: 'Hygiene',
          status: _hygieneStatus(state.currentHygiene),
          value: state.currentHygiene / 100,
          gradient: const [Color(0xFFF7D3C4), Color(0xFFEFA58C)],
        ),
        const SizedBox(height: 14),
        _Meter(
          label: 'Sleep',
          status: _sleepStatus(state.currentSleep),
          value: state.currentSleep / 100,
          gradient: const [Color(0xFFE8C9A8), Color(0xFFC9AF97)],
        ),
        const SizedBox(height: 14),
        _Meter(
          label: 'Play',
          status: _playStatus(state.currentPlay),
          value: state.currentPlay / 100,
          gradient: const [AppTheme.apricot, Color(0xFFE29254)],
        ),
        const SizedBox(height: 18),
        _careTip(state),
        _BondHearts(
          filled: Bond.levelIndexFor(state.friendship) + 1,
          total: Bond.levelCount,
          label: state.bondLabel,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _openTreatPicker,
                child: const Text('Feed'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                onPressed: _play,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                ),
                child: const Text('Play'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                onPressed: _openSpa,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  foregroundColor: theme.colorScheme.onTertiaryContainer,
                ),
                child: const Text('Groom'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            state.bondIsMax
                ? 'Inseparable — the deepest bond 💛'
                : 'Away a while? $_name just wants a little '
                    'attention — never guilt.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _metaLine(Cat cat) {
    final parts = <String>[];
    if (cat.hasLocation) parts.add('Met nearby');
    if (cat.discoveredAt != null) parts.add(_formatDate(cat.discoveredAt!));
    return parts.isEmpty ? 'A treasured companion' : parts.join(' · ');
  }
}

// --- Small pieces ----------------------------------------------------------

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface
          .withValues(alpha: onTap == null ? 0.5 : 0.85),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// A small inline pencil next to the cat's name that opens the rename dialog.
class _PencilButton extends StatelessWidget {
  const _PencilButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      iconSize: 18,
      color: theme.colorScheme.onSurfaceVariant,
      tooltip: 'Rename',
      icon: const Icon(Icons.edit_outlined),
    );
  }
}

class _MoodBadge extends StatelessWidget {
  const _MoodBadge({required this.mood});

  final String mood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF6E8C66),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(mood,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.status,
    required this.value,
    required this.gradient,
  });

  final String label;
  final String status;
  final double value;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = theme.brightness == Brightness.light
        ? const Color(0xFFF0E4D4)
        : const Color(0xFF3C332B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(status,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 12, color: track),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (context, v, _) => Container(
                    height: 12,
                    width: c.maxWidth * v,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BondHearts extends StatelessWidget {
  const _BondHearts({
    required this.filled,
    required this.total,
    required this.label,
  });

  final int filled;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text('Friendship',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Icon(
              Icons.favorite,
              size: 15,
              color: i < filled
                  ? AppTheme.terracotta
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        const SizedBox(width: 8),
        Text(label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _FloaterSpec {
  const _FloaterSpec({required this.id, required this.emoji, required this.dx});

  final int id;
  final String emoji;
  final double dx;
}

/// A single emoji that drifts up and fades, then removes itself via [onDone].
class _Floater extends StatefulWidget {
  const _Floater({
    required super.key,
    required this.emoji,
    required this.onDone,
  });

  final String emoji;
  final VoidCallback onDone;

  @override
  State<_Floater> createState() => _FloaterState();
}

class _FloaterState extends State<_Floater>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -130 * t),
            child: Transform.scale(
              scale: 0.8 + 0.6 * t,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
        );
      },
    );
  }
}

class _HeroSprite extends StatelessWidget {
  const _HeroSprite({required this.cat});

  final Cat cat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget sprite = cat.spriteUrl == null
        ? Icon(Icons.pets, size: 96, color: theme.colorScheme.primary)
        : Image.network(
            cat.spriteUrl!,
            width: 180,
            height: 180,
            fit: BoxFit.contain,
            // Crisp nearest-neighbour scaling for pixel-art sprites.
            filterQuality: FilterQuality.none,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const CircularProgressIndicator(),
            errorBuilder: (context, _, __) =>
                const Icon(Icons.broken_image_outlined, size: 72),
          );
    // A gentle, personality-flavoured idle breathe (respects reduce-motion).
    return CatIdleSprite(traitId: cat.traitId, child: sprite);
  }
}

/// The treat menu shown when the player taps Feed. Tapping a treat pops the
/// sheet with the chosen [Treat].
class _TreatSheet extends StatelessWidget {
  const _TreatSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text('Pick a treat', style: theme.textTheme.titleLarge),
          ),
          for (final treat in kTreats)
            ListTile(
              leading: Text(treat.emoji, style: const TextStyle(fontSize: 28)),
              title: Text(treat.label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
              subtitle: Text('+${treat.bond} bond'),
              trailing: Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
              onTap: () => Navigator.of(context).pop(treat),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.peach,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8C5A2E),
        ),
      ),
    );
  }
}

/// The Story / Details segmented toggle at the top of the sheet.
class _SegTabs extends StatelessWidget {
  const _SegTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _seg(context, 'Story', 0),
          _seg(context, 'Details', 1),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, String label, int i) {
    final theme = Theme.of(context);
    final selected = index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(i),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.ink.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "card back": a warm stat sheet layered as the Details tab. Every figure
/// is a playful, clearly-labelled estimate derived deterministically from the
/// cat's id, so the same cat always reads the same — never presented as fact.
class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.cat,
    required this.friendship,
    required this.care,
    required this.onOpenNook,
  });

  final Cat cat;
  final int friendship;
  final CareState? care;
  final VoidCallback onOpenNook;

  /// The playful life stage, from time known — same thresholds as the timeline.
  String get _growthStage {
    final d = cat.discoveredAt;
    if (d == null) return 'kitten';
    final days = DateTime.now().difference(d).inDays;
    if (days < 30) return 'kitten';
    if (days < 120) return 'young';
    if (days < 365) return 'adult';
    return 'senior';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seed = _stableHash(cat.id);
    final favorite = kTreats[seed % kTreats.length];
    final moods = _idleMoods(seed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FactTile(
          label: 'BREED ESTIMATE',
          value: _breeds[seed % _breeds.length],
          note: 'our friendly best guess',
        ),
        const SizedBox(height: 12),
        _FactTile(
          label: 'AGE & WEIGHT (EST.)',
          value: '${_ages[(seed ~/ 7) % _ages.length]} · ~${_weightKg(seed)} kg',
          note: 'a very healthy loaf',
        ),
        const SizedBox(height: 12),
        _FactTile(
          label: 'FAVOURITE FOOD',
          value: '${favorite.emoji}  ${favorite.label}',
          note: 'a firm favourite of theirs',
        ),
        const SizedBox(height: 12),
        _FactTile(
          label: 'IDLE MOODS',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final m in moods) _MiniChip(label: m)],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'BADGES TOGETHER',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _BadgeChip(
              label: 'First hello',
              icon: Icons.waving_hand_outlined,
              earned: true,
            ),
            _BadgeChip(
              label: 'Best friends',
              icon: Icons.favorite,
              earned: friendship >= 50,
            ),
            const _BadgeChip(
              label: 'A surprise…',
              icon: Icons.help_outline,
              earned: false,
            ),
          ],
        ),
        if (care != null) ...[
          const SizedBox(height: 22),
          Builder(
            builder: (context) {
              final stats = CatStats.fromCare(
                care!,
                growthStage: _growthStage,
                traitId: cat.traitId,
              );
              return Column(
                children: [
                  _PlayStatsCard(stats: stats),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PracticeGroundScreen(
                            catName: cat.name,
                            stats: stats,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.sports_esports_outlined),
                      label: const Text('Practice ground'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 22),
        _GrowthTimeline(discoveredAt: cat.discoveredAt),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: onOpenNook,
            child: const Text('🏡  Visit the nook'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            'Story first, stats second — the estimates are just for fun.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// A read-only preview of the cat's friendly-contest profile (roadmap p3a/b).
/// The numbers come only from care, bond, growth, and personality — never a
/// purchase — so a well-loved cat naturally shines. Contests themselves are not
/// live yet; the honest note says so.
class _PlayStatsCard extends StatelessWidget {
  const _PlayStatsCard({required this.stats});

  final CatStats stats;

  static const _rows = [
    (CatStat.agility, 'Agility'),
    (CatStat.speed, 'Speed'),
    (CatStat.confidence, 'Confidence'),
    (CatStat.curiosity, 'Curiosity'),
    (CatStat.energy, 'Energy'),
    (CatStat.cuteness, 'Cuteness'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: AppTheme.sage),
              const SizedBox(width: 8),
              Text('Play stats',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in _rows) ...[
            _StatBar(label: row.$2, value: stats[row.$1]),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(
            'Friendly contests are coming — no battles, nothing gets hurt, and '
            'never anything you can buy your way through. These grow purely from '
            'your care.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / 100.0,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.sage),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// A gentle "growing up together" timeline. The current life stage is derived
/// from how long you've known the cat — markings and personality never change,
/// only this soft sense of time passing.
class _GrowthTimeline extends StatelessWidget {
  const _GrowthTimeline({required this.discoveredAt});

  final DateTime? discoveredAt;

  static const _stages = ['Kitten', 'Young', 'Adult', 'Senior'];

  int get _index {
    final d = discoveredAt;
    if (d == null) return 0;
    final days = DateTime.now().difference(d).inDays;
    if (days < 30) return 0;
    if (days < 120) return 1;
    if (days < 365) return 2;
    return 3;
  }

  String get _ageLabel {
    final d = discoveredAt;
    if (d == null) return 'newly met';
    final days = DateTime.now().difference(d).inDays;
    if (days < 1) return 'together since today';
    if (days < 30) return 'together $days days';
    final months = days ~/ 30;
    if (months < 12) return 'together $months ${months == 1 ? 'month' : 'months'}';
    final years = days ~/ 365;
    return 'together $years ${years == 1 ? 'year' : 'years'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = _index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GROWING UP TOGETHER',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _ageLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < _stages.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _StagePill(
                  label: _stages[i],
                  reached: i <= index,
                  current: i == index,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Markings and personality never change — only gentle growth.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({
    required this.label,
    required this.reached,
    required this.current,
  });

  final String label;
  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = current
        ? AppTheme.apricot
        : reached
            ? AppTheme.peach
            : theme.colorScheme.surfaceContainerHighest;
    final fg = current
        ? AppTheme.ink
        : reached
            ? const Color(0xFF8C5A2E)
            : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusChip),
        border: current
            ? Border.all(color: AppTheme.terracotta, width: 1.5)
            : null,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: current ? FontWeight.w800 : FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// A single warm fact tile: a caps label over either a [value] (+ optional
/// [note]) or a custom [child] (e.g. a row of chips).
class _FactTile extends StatelessWidget {
  const _FactTile({required this.label, this.value, this.note, this.child});

  final String label;
  final String? value;
  final String? note;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (child != null)
            child!
          else ...[
            Text(
              value ?? '',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A small sage chip used for idle-mood tags.
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusChip),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// An earned or still-locked "badge together". Locked badges show a padlock and
/// muted outline — a gentle nudge, never a scolding.
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    required this.icon,
    required this.earned,
  });

  final String label;
  final IconData icon;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor =
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    final color = earned ? const Color(0xFF8C5A2E) : mutedColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: earned ? AppTheme.peach : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusChip),
        border: earned ? null : Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(earned ? icon : Icons.lock_outline, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// A small, stable hash of the cat id so its playful estimates never change.
int _stableHash(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

const _breeds = [
  'Domestic shorthair',
  'Domestic longhair',
  'Tabby mix',
  'Tuxedo mix',
  'Calico mix',
  'Tortoiseshell mix',
  'Ginger mix',
  'Grey shorthair',
];

const _ages = [
  'a playful kitten',
  '~1 year old',
  '~2 years old',
  '~3 years old',
  '~4 years old',
  '~5 years old',
  'a wise senior',
];

String _weightKg(int seed) {
  final tenths = 32 + (seed % 22); // 3.2–5.3 kg
  return (tenths / 10).toStringAsFixed(1);
}

const _moodPool = [
  'Sunbathe',
  'Loaf',
  'Chirp',
  'Knead',
  'Pounce',
  'Doze',
  'Perch',
  'Explore',
  'Snuggle',
  'Groom',
];

List<String> _idleMoods(int seed) {
  final pool = List<String>.from(_moodPool);
  final picks = <String>[];
  var s = seed;
  while (picks.length < 3 && pool.isNotEmpty) {
    picks.add(pool.removeAt(s % pool.length));
    s = (s ~/ 3) + 17;
  }
  return picks;
}

/// The tappable collar chip in the header: shows the equipped collar (tinted to
/// its colour) or a soft "add a collar" prompt, and opens the wardrobe.
class _CollarChip extends StatelessWidget {
  const _CollarChip({required this.collar, required this.onTap});

  final Collar? collar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = collar;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: c != null
              ? c.color.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusChip),
          border: c != null
              ? null
              : Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c != null ? c.emoji : '＋',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 5),
            Text(
              c != null ? c.label : 'Collar',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

String _titleCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

String _hungerStatus(int v) {
  if (v >= 85) return 'Full & happy';
  if (v >= 65) return 'Content';
  if (v >= 45) return 'Feeling snacky';
  return 'Hungry';
}

String _happyStatus(int v) {
  if (v >= 85) return 'Blissful';
  if (v >= 65) return 'Pretty content';
  if (v >= 45) return 'A bit restless';
  return 'Needs cheering';
}

String _hygieneStatus(int v) {
  if (v >= 85) return 'Fresh & clean';
  if (v >= 60) return 'Looking tidy';
  if (v >= 40) return 'A bit of dust';
  return 'Ready for a brush';
}

String _sleepStatus(int v) {
  if (v >= 85) return 'Well-napped';
  if (v >= 60) return 'Rested';
  if (v >= 40) return 'A little sleepy';
  return 'Yawning';
}

String _playStatus(int v) {
  if (v >= 85) return 'Played out & happy';
  if (v >= 60) return 'Content';
  if (v >= 40) return 'Could use a little love';
  return 'Wants to play';
}
