import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../safety/data/age_gate.dart';
import '../../safety/domain/age_bracket.dart';
import '../../safety/domain/report_reason.dart';
import '../../safety/presentation/report_block_sheet.dart';
import '../data/discovery_repository.dart';
import '../data/social_repository.dart';
import '../domain/discovery_profile.dart';
import '../domain/safe_play.dart';

/// Adults-only, opt-in cat-keeper discovery (roadmap p3c).
///
/// This is the one social surface that reaches beyond an already-known friend
/// code, so it is deliberately narrow and honest about it: 18+ only on both
/// sides, mutual opt-in, no location, no free text, and never a stranger's cats
/// — only a rotatable code + a cat count, with report/block one tap away. A
/// minor never sees this screen's live body (ADR 0004; docs/08 §Minors). While
/// live social is off it shows an honest "coming when we can host it safely"
/// state, never a simulated pool.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  bool _optIn = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await ref.read(socialRepositoryProvider).discoveryOptIn();
      if (!mounted) return;
      setState(() {
        _optIn = value;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _setOptIn(bool value) async {
    setState(() => _optIn = value);
    try {
      await ref.read(socialRepositoryProvider).setDiscoveryOptIn(value);
      ref.invalidate(discoveryProfilesProvider);
    } catch (_) {
      if (mounted) setState(() => _optIn = !value);
    }
  }

  Future<void> _add(DiscoveryProfile p) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    String result;
    try {
      result = await ref.read(discoveryRepositoryProvider).add(p.id);
    } catch (_) {
      result = 'error';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(discoveryProfilesProvider);
    messenger.showSnackBar(SnackBar(content: Text(_messageFor(result))));
  }

  String _messageFor(String result) => switch (result) {
        'ok' => 'Request sent! 🐾',
        'self' => "That's you 🙂",
        'blocked' => "Can't connect right now.",
        'exists' => "You're already connected (or a request is pending).",
        'rate_limited' =>
          "That's a lot of requests in a short time — try again a little later.",
        'restricted' => "Discovery isn't available right now.",
        'not_eligible' => 'Turn on discovery above to connect with keepers.',
        'not_found' => "That keeper isn't discoverable anymore.",
        _ => 'Something went wrong — try again.',
      };

  void _report(DiscoveryProfile p) {
    final label = p.handle.isEmpty ? 'this keeper' : 'keeper ${p.handle}';
    unawaited(showReportBlockSheet(
      context,
      targetType: ReportTargetType.profile,
      targetId: p.id,
      subjectLabel: label,
      blockUserId: p.id,
      onBlocked: () => ref.invalidate(discoveryProfilesProvider),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bracket = ref.watch(ageBracketProvider);
    final caps = ref.watch(socialCapabilitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Discover keepers')),
      body: SafeArea(child: _body(bracket, caps)),
    );
  }

  Widget _body(AgeBracket bracket, SocialCapabilities caps) {
    // Adults only — a minor never reaches the live pool.
    if (bracket != AgeBracket.adult) {
      return const _AdultOnlyNotice();
    }
    // Live social off (master switch / geo-gate): honest gated state.
    if (!SafePlay.discoveryAllowed(caps)) {
      return const _DiscoveryGatedState();
    }
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _OptInCard(value: _optIn, onChanged: _setOptIn),
        const SizedBox(height: 20),
        if (_optIn) ...[
          const _SectionLabel('KEEPERS YOU MIGHT KNOW'),
          const SizedBox(height: 8),
          _pool(),
        ] else
          const _OptInPrompt(),
      ],
    );
  }

  Widget _pool() {
    final theme = Theme.of(context);
    final pool = ref.watch(discoveryProfilesProvider);
    return pool.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _Card(
        child: Text(
          "Couldn't load the discovery pool just now.",
          style: theme.textTheme.bodyMedium,
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return _Card(
            child: Text(
              'No other keepers are open to discovery right now. Check back '
              'later — you\'re listed too, so someone may reach out. 🐾',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final p in list)
              _KeeperRow(
                profile: p,
                busy: _busy,
                onAdd: () => _add(p),
                onReport: () => _report(p),
              ),
          ],
        );
      },
    );
  }
}

// --- Pieces ------------------------------------------------------------------

class _OptInCard extends StatelessWidget {
  const _OptInCard({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        title: const Text('Let other keepers find me'),
        subtitle: Text(
          'Adults only, and only if you switch it on. Others see just your '
          'friend code and how many cats you keep — never your name, never any '
          'location. Turn it off any time.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _OptInPrompt extends StatelessWidget {
  const _OptInPrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.travel_explore_outlined,
              color: theme.colorScheme.primary, size: 32),
          const SizedBox(height: 10),
          Text('Discovery is off',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Switch on “Let other keepers find me” to browse other adults who '
            'have opted in, and to appear for them. It stays friends-first: '
            'connecting still sends a friend request they can accept or decline.',
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

class _KeeperRow extends StatelessWidget {
  const _KeeperRow({
    required this.profile,
    required this.busy,
    required this.onAdd,
    required this.onReport,
  });

  final DiscoveryProfile profile;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cats = profile.catsCount;
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
                Text(
                  profile.handle.isEmpty ? 'A keeper' : profile.handle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  cats == 1 ? 'Keeps 1 cat' : 'Keeps $cats cats',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: busy ? null : onAdd,
            child: const Text('Add'),
          ),
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

class _DiscoveryGatedState extends StatelessWidget {
  const _DiscoveryGatedState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Coming when we can host it safely',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Meeting new keepers will be adults-only and opt-in, showing just '
              'a friend code and a cat count — never a name, never a location, '
              'and never a stranger\'s cats. Reporting and blocking are built '
              'in. It turns on once the safeguards are cleared.',
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

class _AdultOnlyNotice extends StatelessWidget {
  const _AdultOnlyNotice();

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
            Text('For grown-up keepers',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Meeting new keepers is an adults-only space, so no one under 18 '
              'is ever shown to — or shown — a stranger. You can still add '
              'friends you already know by their code, and enjoy your whole '
              'CatDex. 🐾',
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
