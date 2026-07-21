import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../safety/domain/report_reason.dart';
import '../../safety/presentation/report_block_sheet.dart';
import '../data/social_repository.dart';
import '../domain/safe_play.dart';
import '../domain/showcase_cat.dart';

/// Visiting an accepted friend's showcase (roadmap p3c). Read-only, friends-only,
/// and free of any location: the cats come from the guarded `list_friend_showcase`
/// RPC (migration 0014), which returns only safe cosmetic fields. Report/block is
/// one tap away in the app bar. The whole surface is held behind [kSocialLive] —
/// while off, it shows an honest gated state and never touches the network.
class VisitScreen extends ConsumerWidget {
  const VisitScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  final String friendId;
  final String friendName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$friendName's cats"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report or block',
            onPressed: () => showReportBlockSheet(
              context,
              targetType: ReportTargetType.profile,
              targetId: friendId,
              subjectLabel: friendName,
              blockUserId: friendId,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: kSocialLive ? _live(ref) : const _GatedState(),
      ),
    );
  }

  Widget _live(WidgetRef ref) {
    final showcase = ref.watch(friendShowcaseProvider(friendId));
    return showcase.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Message(
        'We couldn\'t open this showcase right now. Please try again.',
      ),
      data: (cats) => cats.isEmpty
          ? _Message('$friendName hasn\'t put any cats on show yet.')
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: cats.length,
              itemBuilder: (_, i) => _ShowcaseTile(cat: cats[i]),
            ),
    );
  }
}

class _ShowcaseTile extends StatelessWidget {
  const _ShowcaseTile({required this.cat});

  final ShowcaseCat cat;

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
          Text(
            cat.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(cat.growthLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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

/// Shown while [kSocialLive] is off — honest about what visiting will be and the
/// safeguards, never a simulated showcase.
class _GatedState extends StatelessWidget {
  const _GatedState();

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
              const Text('🏡', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Visiting is coming',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Drop by an accepted friend\'s showcase to admire their cats. '
                'Friends-only, never a public feed, and no location is ever '
                'shared — just the cats they choose to show. Reporting is always '
                'one tap away. We\'ll switch it on once we can host it safely.',
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
