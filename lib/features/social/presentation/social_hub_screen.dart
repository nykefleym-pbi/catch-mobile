import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../safety/data/age_gate.dart';
import '../../safety/domain/age_bracket.dart';
import '../../safety/domain/report_reason.dart';
import '../../safety/presentation/report_block_sheet.dart';
import '../data/social_repository.dart';
import '../domain/friend.dart';

/// The social hub (roadmap p3c) — friends, a cosmetic showcase, and honest
/// previews of the trading (p3d) and friendly-contest (p3a/b) systems that are
/// still being built to be safe. Everything here is gated by the age band
/// (ADR 0004): under-13 sees a gentle explainer, minors get conservative
/// defaults, and live trading/contests stay behind the master social switch
/// until the moderation + realtime groundwork exists.
class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen> {
  final _codeField = TextEditingController();
  String? _myCode;
  bool _showcase = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeField.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(socialRepositoryProvider);
    try {
      final code = await repo.friendCode();
      final showcase = await repo.showcaseToFriends();
      if (!mounted) return;
      setState(() {
        _myCode = code;
        _showcase = showcase;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _addFriend() async {
    final code = _codeField.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    String result;
    try {
      result = await ref.read(socialRepositoryProvider).requestByCode(code);
    } catch (_) {
      result = 'error';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == 'ok') _codeField.clear();
    ref.invalidate(friendsProvider);
    messenger.showSnackBar(SnackBar(content: Text(_messageFor(result))));
  }

  String _messageFor(String result) => switch (result) {
        'ok' => 'Request sent! 🐾',
        'not_found' => 'No guardian found with that code.',
        'self' => "That's your own code 🙂",
        'blocked' => "Can't connect right now.",
        'exists' => "You're already connected (or a request is pending).",
        _ => 'Something went wrong — try again.',
      };

  Future<void> _setShowcase(bool value) async {
    setState(() => _showcase = value);
    try {
      await ref.read(socialRepositoryProvider).setShowcaseToFriends(value);
    } catch (_) {
      if (mounted) setState(() => _showcase = !value);
    }
  }

  Future<void> _respond(Friend f, {required bool accept}) async {
    await ref.read(socialRepositoryProvider).respond(f.id, accept: accept);
    ref.invalidate(friendsProvider);
  }

  void _reportFriend(Friend f) {
    unawaited(showReportBlockSheet(
      context,
      targetType: ReportTargetType.profile,
      targetId: f.id,
      subjectLabel: f.label,
      blockUserId: f.id,
      onBlocked: () async {
        await ref.read(socialRepositoryProvider).remove(f.id);
        ref.invalidate(friendsProvider);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bracket = ref.watch(ageBracketProvider);
    final caps = ref.watch(socialCapabilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends & play')),
      body: SafeArea(
        child: _body(theme, bracket, caps),
      ),
    );
  }

  Widget _body(ThemeData theme, AgeBracket bracket, SocialCapabilities caps) {
    if (bracket == AgeBracket.unknown) {
      return _AgePrompt(
        onSelect: (b) async {
          await ref.read(ageBracketProvider.notifier).set(b);
        },
      );
    }
    if (!caps.canUseSocial) {
      return const _Under13Notice();
    }
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _FriendCodeCard(code: _myCode),
        const SizedBox(height: 12),
        _AddFriendCard(
          controller: _codeField,
          busy: _busy,
          onAdd: _addFriend,
        ),
        const SizedBox(height: 20),
        const _SectionLabel('YOUR FRIENDS'),
        const SizedBox(height: 8),
        _friendsList(theme),
        const SizedBox(height: 20),
        const _SectionLabel('YOUR SHOWCASE'),
        const SizedBox(height: 8),
        _ShowcaseCard(
          enabled: caps.canShowcaseToFriends,
          value: _showcase,
          onChanged: caps.canShowcaseToFriends ? _setShowcase : null,
        ),
        const SizedBox(height: 20),
        const _SectionLabel('COMING WHEN WE CAN HOST IT SAFELY'),
        const SizedBox(height: 8),
        const _ComingSoonCard(
          icon: Icons.swap_horiz,
          title: 'Cosmetic trading',
          body: 'Swap collars and decor with friends — cosmetics only, never '
              'anything you can win with or buy your way through, and never for '
              'real money. Only between friends, with reporting built in.',
        ),
        const SizedBox(height: 12),
        const _ComingSoonCard(
          icon: Icons.emoji_events_outlined,
          title: 'Friendly contests',
          body: 'Zoomie races and playful challenges. No battles, nothing gets '
              'hurt, and skill & care always beat spending — a cat\'s stats come '
              'only from your kindness, never a purchase.',
        ),
      ],
    );
  }

  Widget _friendsList(ThemeData theme) {
    final friends = ref.watch(friendsProvider);
    return friends.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _MutedCard(
        child: Text(
          "Couldn't load your friends just now.",
          style: theme.textTheme.bodyMedium,
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return _MutedCard(
            child: Text(
              'No friends yet. Share your code above to connect with someone '
              'you already know.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final f in list)
              _FriendRow(
                friend: f,
                onAccept: () => _respond(f, accept: true),
                onDecline: () => _respond(f, accept: false),
                onReport: () => _reportFriend(f),
              ),
          ],
        );
      },
    );
  }
}

// --- Pieces ------------------------------------------------------------------

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

class _FriendCodeCard extends StatelessWidget {
  const _FriendCodeCard({required this.code});
  final String? code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your friend code',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 4),
                Text(
                  code ?? '••••••',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          if (code != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy',
              onPressed: () {
                unawaited(Clipboard.setData(ClipboardData(text: code!)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied')),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AddFriendCard extends StatelessWidget {
  const _AddFriendCard({
    required this.controller,
    required this.busy,
    required this.onAdd,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !busy,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: "Add a friend's code",
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : onAdd,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.onAccept,
    required this.onDecline,
    required this.onReport,
  });

  final Friend friend;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
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
            child: const Icon(Icons.pets, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  friend.isIncoming
                      ? 'Wants to be friends'
                      : friend.isPending
                          ? 'Request sent'
                          : 'Friend',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (friend.isIncoming) ...[
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppTheme.sage),
              tooltip: 'Accept',
              onPressed: onAccept,
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Decline',
              onPressed: onDecline,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.more_horiz),
              tooltip: 'Report or block',
              onPressed: onReport,
            ),
        ],
      ),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: enabled && value,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show my cats to friends'),
            subtitle: Text(
              enabled
                  ? 'Accepted friends can admire your CatDex. Never public, and '
                      'never any location.'
                  : 'Showcasing stays off for under-18s, for safety.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                ),
                child: Text('Soon',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Under13Notice extends StatelessWidget {
  const _Under13Notice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Social play comes later',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Adding friends and sharing cats isn\'t part of the under-13 '
              'experience. You can still meet, care for, and grow your whole '
              'CatDex — enjoy the cats! 🐾',
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

class _AgePrompt extends StatelessWidget {
  const _AgePrompt({required this.onSelect});
  final ValueChanged<AgeBracket> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'One quick thing',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us your age band so we can keep playing-with-others safe. '
              'We only keep a rough band — never your birthday.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            for (final entry in const [
              (AgeBracket.under13, 'Under 13'),
              (AgeBracket.teen, '13 to 17'),
              (AgeBracket.adult, '18 or older'),
            ]) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => onSelect(entry.$1),
                  child: Text(entry.$2),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
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

class _MutedCard extends StatelessWidget {
  const _MutedCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _Card(child: child);
}
