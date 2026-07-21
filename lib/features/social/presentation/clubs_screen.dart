import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../safety/domain/report_reason.dart';
import '../../safety/presentation/report_block_sheet.dart';
import '../data/club_repository.dart';
import '../data/social_repository.dart';
import '../domain/club.dart';
import '../domain/friend.dart';
import '../domain/safe_play.dart';

/// Clubs + cooperative challenges (roadmap p3c) — small, kind, friends-based
/// groups working toward gentle shared goals. Caring together, never competing
/// to spend: contributing to a goal takes no purchase, and completing it grants
/// only a celebratory state. Membership is invite-only between accepted friends,
/// there is no chat, and a co-member's identity is shown only to their friends —
/// a minor never learns a stranger's handle. The whole surface is held behind
/// [kSocialLive]: while off it shows an honest gated state and never a simulated
/// feed.
class ClubsScreen extends ConsumerWidget {
  const ClubsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clubs & challenges')),
      body: const SafeArea(
        top: false,
        child: kSocialLive ? _ClubsList() : _ClubsGatedState(),
      ),
    );
  }
}

class _ClubsList extends ConsumerWidget {
  const _ClubsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(myClubsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createClub(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New club'),
      ),
      body: clubs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _CenteredMessage(
          "We couldn't load your clubs just now. Please try again.",
        ),
        data: (list) {
          if (list.isEmpty) return const _EmptyClubs();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ClubCard(club: list[i]),
          );
        },
      ),
    );
  }

  Future<void> _createClub(BuildContext context, WidgetRef ref) async {
    final name = await _promptText(
      context,
      title: 'New club',
      label: 'Club name',
      action: 'Create',
    );
    if (name == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final (outcome, _) = await ref.read(clubRepositoryProvider).create(name);
    ref.invalidate(myClubsProvider);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }
}

class _ClubCard extends ConsumerWidget {
  const _ClubCard({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (club.isInvited) return _InviteCard(club: club);
    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ClubDetailScreen(clubId: club.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: const Icon(Icons.groups, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(club.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${club.memberCount} '
                        '${club.memberCount == 1 ? 'member' : 'members'}'
                        '${club.isOwner ? ' • you host' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            if (club.challenge != null) ...[
              const SizedBox(height: 12),
              _ChallengeBar(challenge: club.challenge!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invitation to join',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 4),
          Text(club.name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _respond(context, ref, accept: true),
                  child: const Text('Join'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respond(context, ref, accept: false),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, WidgetRef ref,
      {required bool accept}) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(clubRepositoryProvider)
        .respondInvite(club.id, accept: accept);
    ref.invalidate(myClubsProvider);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }
}

/// The club room: the shared goal, the roster, invite a friend, and leave.
class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen({super.key, required this.clubId});

  final String clubId;

  Club? _find(List<Club>? list) {
    if (list == null) return null;
    for (final c in list) {
      if (c.id == clubId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(myClubsProvider);
    final club = _find(clubs.valueOrNull);
    return Scaffold(
      appBar: AppBar(
        title: Text(club?.name ?? 'Club'),
        actions: [
          if (club != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Report club',
              onPressed: () => showReportBlockSheet(
                context,
                targetType: ReportTargetType.club,
                targetId: club.id,
                subjectLabel: club.name,
              ),
            ),
          if (club != null)
            IconButton(
              icon: Icon(club.isOwner
                  ? Icons.delete_outline
                  : Icons.logout_outlined),
              tooltip: club.isOwner ? 'Close club' : 'Leave club',
              onPressed: () => _leave(context, ref, club),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: clubs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const _CenteredMessage("We couldn't open this club just now."),
          data: (_) => club == null
              ? const _CenteredMessage('This club is no longer here.')
              : _ClubBody(club: club),
        ),
      ),
      floatingActionButton: club == null || !club.isActive
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _invite(context, ref, club),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite friend'),
            ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Club club) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(club.isOwner ? 'Close this club?' : 'Leave this club?'),
        content: Text(club.isOwner
            ? 'As the host, closing the club removes it for everyone. Cats and '
                'progress elsewhere are untouched.'
            : 'You can be invited again later. Your cats are untouched.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(club.isOwner ? 'Close' : 'Leave'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final outcome = await ref.read(clubRepositoryProvider).leave(club.id);
    ref.invalidate(myClubsProvider);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    navigator.pop();
  }

  Future<void> _invite(BuildContext context, WidgetRef ref, Club club) async {
    final members = await ref.read(clubMembersProvider(club.id).future);
    final inClub = members.map((m) => m.profileId).toSet();
    final friends = await ref.read(friendsProvider.future);
    final invitable = friends
        .where((f) => f.isAccepted && !inClub.contains(f.id))
        .toList();
    if (!context.mounted) return;
    if (invitable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No friends left to invite. Add a friend first 🐾'),
      ));
      return;
    }
    final picked = await showModalBottomSheet<Friend>(
      context: context,
      builder: (_) => _FriendPickerSheet(friends: invitable),
    );
    if (picked == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final outcome =
        await ref.read(clubRepositoryProvider).invite(club.id, picked.id);
    ref.invalidate(clubMembersProvider(club.id));
    ref.invalidate(myClubsProvider);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }
}

class _ClubBody extends ConsumerWidget {
  const _ClubBody({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _ChallengeSection(club: club),
        const SizedBox(height: 20),
        const _SectionLabel('MEMBERS'),
        const SizedBox(height: 8),
        _RosterList(club: club),
      ],
    );
  }
}

class _ChallengeSection extends ConsumerWidget {
  const _ChallengeSection({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenge = club.challenge;
    if (challenge == null) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No shared goal yet',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              club.isOwner
                  ? 'Set a gentle goal your club can reach by caring for your '
                      'own cats — together.'
                  : 'The host hasn\'t set a goal yet. Check back soon!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (club.isOwner) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _startChallenge(context, ref),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Set a shared goal'),
              ),
            ],
          ],
        ),
      );
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(challenge.kind.emoji,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(challenge.kind.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (challenge.completed)
                Text('🎉', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          _ChallengeBar(challenge: challenge),
          const SizedBox(height: 12),
          if (challenge.completed)
            Text('Goal complete — lovely teamwork!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.sage,
                  fontWeight: FontWeight.w700,
                ))
          else
            FilledButton.icon(
              onPressed: () => _contribute(context, ref),
              icon: const Icon(Icons.favorite_outline),
              label: const Text('Log a good deed'),
            ),
        ],
      ),
    );
  }

  Future<void> _contribute(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(clubRepositoryProvider).contribute(club.id);
    ref.invalidate(myClubsProvider);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  Future<void> _startChallenge(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<(ClubChallengeKind, int)>(
      context: context,
      builder: (_) => const _StartChallengeDialog(),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(clubRepositoryProvider)
        .startChallenge(club.id, result.$1, result.$2);
    ref.invalidate(myClubsProvider);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }
}

class _ChallengeBar extends StatelessWidget {
  const _ChallengeBar({required this.challenge});

  final ClubChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: challenge.fraction,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: challenge.completed ? AppTheme.sage : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text('${challenge.progress} / ${challenge.goal}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}

class _RosterList extends ConsumerWidget {
  const _RosterList({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roster = ref.watch(clubMembersProvider(club.id));
    return roster.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _Card(
        child: Text("Couldn't load members just now.",
            style: theme.textTheme.bodyMedium),
      ),
      data: (members) => Column(
        children: [
          for (final m in members)
            _MemberRow(
              member: m,
              onReport: () => showReportBlockSheet(
                context,
                targetType: ReportTargetType.profile,
                targetId: m.profileId,
                subjectLabel: m.label,
                blockUserId: m.profileId,
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onReport});

  final ClubMember member;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Icon(member.isOwner ? Icons.star : Icons.person, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  member.isInvited
                      ? 'Invited'
                      : member.isOwner
                          ? 'Host'
                          : member.isFriend
                              ? 'Your friend'
                              : 'Club member',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Report',
            onPressed: onReport,
          ),
        ],
      ),
    );
  }
}

class _FriendPickerSheet extends StatelessWidget {
  const _FriendPickerSheet({required this.friends});

  final List<Friend> friends;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text('Invite a friend',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: friends.length,
              itemBuilder: (_, i) {
                final f = friends[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: const Icon(Icons.pets, size: 18),
                  ),
                  title: Text(f.label),
                  onTap: () => Navigator.of(context).pop(f),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StartChallengeDialog extends StatefulWidget {
  const _StartChallengeDialog();

  @override
  State<_StartChallengeDialog> createState() => _StartChallengeDialogState();
}

class _StartChallengeDialogState extends State<_StartChallengeDialog> {
  ClubChallengeKind _kind = ClubChallengeKind.care;
  int _goal = 20;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set a shared goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final k in ClubChallengeKind.values)
                ChoiceChip(
                  label: Text('${k.emoji} ${k.label}'),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Goal: $_goal good deeds'),
          Slider(
            value: _goal.toDouble(),
            min: 5,
            max: 200,
            divisions: 39,
            label: '$_goal',
            onChanged: (v) => setState(() => _goal = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_kind, _goal)),
          child: const Text('Start'),
        ),
      ],
    );
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  int maxLength = 40,
}) {
  final controller = TextEditingController();
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
            if (text.isEmpty) return;
            Navigator.of(ctx).pop(text);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _EmptyClubs extends StatelessWidget {
  const _EmptyClubs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No clubs yet',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Start a small, kind club and invite a friend or two. Then set a '
              'gentle shared goal you\'ll reach by caring for your own cats — '
              'together.',
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

/// Shown while [kSocialLive] is off — honest about what clubs will be and the
/// safeguards, never a simulated feed.
class _ClubsGatedState extends StatelessWidget {
  const _ClubsGatedState();

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
              const Text('🧶', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Clubs are coming',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Team up in small, kind clubs for gentle shared goals — caring '
                'together, never competing to spend. Invite-only between friends '
                'you\'ve accepted, no chat, no location, moderated, and safe for '
                'younger guardians. We\'ll switch it on once we can host it '
                'safely.',
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
