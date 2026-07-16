import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/widgets/placeholder_scaffold.dart';
import '../data/guardian_repository.dart';
import '../domain/guardian_profile.dart';

/// Guardian profile: identity, rank, and the kindness stats that earn it.
/// Rank is grown by caring for cats, never combat (docs/product/01-vision.md).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    if (!Env.hasSupabase) {
      return const PlaceholderScaffold(
        title: 'Guardian',
        icon: Icons.person_outline,
        message: 'This build has no backend configured,\n'
            'so your Guardian profile can\'t be loaded.',
      );
    }

    final profile = ref.watch(guardianProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(guardianProfileProvider),
        ),
        data: _content,
      ),
    );
  }

  Widget _content(GuardianProfile p) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(guardianProfileProvider);
        await ref.read(guardianProfileProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _Header(profile: p, onEdit: () => _editName(p.displayName)),
          const SizedBox(height: 24),
          _RankCard(profile: p),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.pets,
                  value: '${p.catsCount}',
                  label: 'Cats',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.favorite,
                  value: '${p.totalBond}',
                  label: 'Total bond',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.volunteer_activism,
                  value: '${p.score}',
                  label: 'Kindness',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _PrivacyCard(),
        ],
      ),
    );
  }

  Future<void> _editName(String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your Guardian name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Whisker Warden'),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await ref.read(guardianRepositoryProvider).setDisplayName(result);
    if (!mounted) return;
    ref.invalidate(guardianProfileProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Guardian name updated ✨'),
          duration: Duration(seconds: 1),
        ),
      );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onEdit});

  final GuardianProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.displayName ?? 'Guest Guardian';
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.volunteer_activism,
            size: 34,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.rankLabel, style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              )),
              const SizedBox(height: 2),
              Text(name, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit Guardian name',
        ),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.profile});

  final GuardianProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Guardian rank', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  profile.rankLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: profile.rankProgress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 14,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.rankIsMax
                  ? 'The highest honour — a true friend to cats 💛'
                  : '${profile.pointsToNextRank} kindness to your next rank',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your privacy is protected. Locations are only ever stored '
                'fuzzed, and the photos you capture are never saved — they are '
                'discarded the moment a companion is generated.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't load your Guardian profile."),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
