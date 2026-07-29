import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/guardian_profile.dart';

/// The Guardian rank "impact journey" (roadmap p4a): the full ladder of tiers a
/// player climbs — earned entirely through kindness (caring for cats), never
/// combat (docs/product/01-vision.md). Reached tiers are celebrated; the next
/// one shows exactly how much gentle care remains.
class GuardianJourneyScreen extends StatelessWidget {
  const GuardianJourneyScreen({required this.profile, super.key});

  final GuardianProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiers = GuardianRank.tiers;
    final currentIndex = GuardianRank.indexFor(profile.score);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                _RoundBack(onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 8),
                Text(
                  'Your journey',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CurrentRankCard(profile: profile),
            const SizedBox(height: 20),
            Text(
              'THE PATH OF KINDNESS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < tiers.length; i++)
              _TierRow(
                tier: tiers[i],
                reached: i <= currentIndex,
                current: i == currentIndex,
                isLast: i == tiers.length - 1,
              ),
            const SizedBox(height: 8),
            Text(
              'Rank grows through kindness — caring for the cats you meet — '
              'never battles.',
              style: theme.textTheme.bodySmall?.copyWith(
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

class _CurrentRankCard extends StatelessWidget {
  const _CurrentRankCard({required this.profile});

  final GuardianProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextLine = profile.rankIsMax
        ? 'The highest rank — thank you for every kindness 💛'
        : '${profile.pointsToNextRank} more kindness to '
            '${GuardianRank.tiers[GuardianRank.indexFor(profile.score) + 1].name}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT RANK',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const AppAssetImage(AppAssets.guardian, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  profile.rankLabel,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: profile.rankProgress,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.6),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.terracotta),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const AppAssetImage(AppAssets.experience, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nextLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.reached,
    required this.current,
    required this.isLast,
  });

  final GuardianTier tier;
  final bool reached;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = current
        ? AppTheme.terracotta
        : reached
            ? AppTheme.sage
            : theme.colorScheme.surfaceContainerHighest;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: current
                      ? Border.all(color: AppTheme.terracotta, width: 2)
                      : null,
                ),
                child: Icon(
                  reached ? Icons.pets : Icons.lock_outline,
                  size: 13,
                  color: reached
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: current ? FontWeight.w800 : FontWeight.w700,
                      color: reached
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tier.threshold == 0
                        ? 'where every Guardian begins'
                        : 'at ${tier.threshold} kindness',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (current)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                "You're here",
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.terracotta,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
