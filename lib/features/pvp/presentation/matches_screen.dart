import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../safety/data/age_gate.dart';
import '../../social/data/social_repository.dart';
import '../../social/domain/friend.dart';
import '../../social/domain/safe_play.dart';
import '../data/match_repository.dart';
import '../domain/match.dart';

/// The live, friends-only friendly-contest surface (roadmap p3a/b). A contest
/// can only ever be between two ACCEPTED friends — there is no stranger queue —
/// and the age gate (teen + adult only) is enforced server-side by the match
/// RPCs (migrations 0012 + 0013), so a modified client can't reach it around the
/// ban. The whole surface is held behind [kSocialLive]: while that master switch
/// is off, this renders an honest "coming when we can host it safely" state and
/// never touches the network.
class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  MatchMode _mode = MatchMode.zoomies;
  String? _opponentId;
  bool _busy = false;

  Future<void> _send() async {
    final opponent = _opponentId;
    if (opponent == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final outcome =
        await ref.read(matchRepositoryProvider).challenge(opponent, _mode);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    ref.invalidate(outgoingMatchesProvider);
  }

  Future<void> _respond(Match m, {required bool accept}) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome =
        await ref.read(matchRepositoryProvider).respond(m.id, accept: accept);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    ref.invalidate(incomingMatchesProvider);
  }

  Future<void> _cancel(Match m) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(matchRepositoryProvider).cancel(m.id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    ref.invalidate(outgoingMatchesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(socialCapabilitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Friendly contests')),
      body: SafeArea(
        top: false,
        child: (!kSocialLive || !caps.canCompete)
            ? _GatedState(canCompete: caps.canCompete)
            : _live(context),
      ),
    );
  }

  Widget _live(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text('Challenge a friend',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _ModePicker(
          selected: _mode,
          onSelect: (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 16),
        friends.when(
          loading: () =>
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )),
          error: (_, __) => const Text('Could not load your friends.'),
          data: (list) => _FriendPicker(
            friends: [for (final f in list) if (f.isAccepted) f],
            selectedId: _opponentId,
            onSelect: (id) => setState(() => _opponentId = id),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_opponentId == null || _busy) ? null : _send,
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('Send friendly challenge'),
        ),
        const SizedBox(height: 24),
        _InvitesSection(
          title: 'INVITES FOR YOU',
          provider: incomingMatchesProvider,
          builder: (m) => _IncomingTile(
            match: m,
            onAccept: () => _respond(m, accept: true),
            onDecline: () => _respond(m, accept: false),
          ),
          emptyLine: 'No invites right now.',
        ),
        const SizedBox(height: 16),
        _InvitesSection(
          title: 'INVITES YOU SENT',
          provider: outgoingMatchesProvider,
          builder: (m) => _OutgoingTile(match: m, onCancel: () => _cancel(m)),
          emptyLine: 'You haven\'t sent any invites.',
        ),
      ],
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.selected, required this.onSelect});

  final MatchMode selected;
  final ValueChanged<MatchMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in MatchMode.values)
          ChoiceChip(
            selected: m == selected,
            onSelected: (_) => onSelect(m),
            avatar: Text(m.emoji),
            label: Text(m.label),
          ),
      ],
    );
  }
}

class _FriendPicker extends StatelessWidget {
  const _FriendPicker({
    required this.friends,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Friend> friends;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Text(
          'Add a friend first — contests are always between friends.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Column(
      children: [
        for (final f in friends)
          _FriendRow(
            friend: f,
            selected: f.id == selectedId,
            onTap: () => onSelect(f.id),
          ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.selected,
    required this.onTap,
  });

  final Friend friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.10)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(friend.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitesSection extends ConsumerWidget {
  const _InvitesSection({
    required this.title,
    required this.provider,
    required this.builder,
    required this.emptyLine,
  });

  final String title;
  final AutoDisposeFutureProvider<List<Match>> provider;
  final Widget Function(Match) builder;
  final String emptyLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 8),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (_, __) => Text('Could not load invites.',
              style: theme.textTheme.bodySmall),
          data: (list) => list.isEmpty
              ? Text(emptyLine,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
              : Column(children: [for (final m in list) builder(m)]),
        ),
      ],
    );
  }
}

class _IncomingTile extends StatelessWidget {
  const _IncomingTile({
    required this.match,
    required this.onAccept,
    required this.onDecline,
  });

  final Match match;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final mode = match.mode;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(mode?.emoji ?? '🐾',
            style: const TextStyle(fontSize: 24)),
        title: Text(mode?.label ?? 'Friendly contest'),
        subtitle: Text(mode?.blurb ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Decline',
              onPressed: onDecline,
            ),
            IconButton(
              icon: const Icon(Icons.check_circle),
              tooltip: 'Accept',
              color: Theme.of(context).colorScheme.primary,
              onPressed: onAccept,
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingTile extends StatelessWidget {
  const _OutgoingTile({required this.match, required this.onCancel});

  final Match match;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final mode = match.mode;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(mode?.emoji ?? '🐾',
            style: const TextStyle(fontSize: 24)),
        title: Text(mode?.label ?? 'Friendly contest'),
        subtitle: const Text('Waiting for a reply…'),
        trailing: TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ),
    );
  }
}

/// Shown while [kSocialLive] is off, or to a player whose age band can't compete.
/// Honest about what's coming and the safeguards — never a simulated contest.
class _GatedState extends StatelessWidget {
  const _GatedState({required this.canCompete});

  final bool canCompete;

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
              const Text('🏅', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                canCompete
                    ? 'Friendly contests are coming'
                    : 'A cozy, solo warm-up for now',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                canCompete
                    ? 'Zoomie races and playful challenges with your friends. No '
                        'battles, nothing gets hurt, and skill & care always beat '
                        'spending — a cat\'s stats come only from your kindness, '
                        'never a purchase. Friends-only, with reporting built in. '
                        'We\'ll switch it on once we can host it safely.'
                    : 'Friendly contests with other guardians are part of the '
                        'older-guardian experience. You can always warm up solo '
                        'in any cat\'s Practice ground — no opponent, just play.',
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
