import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/placeholder_scaffold.dart';
import '../../../data/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../catdex/data/cats_repository.dart';
import '../data/guardian_repository.dart';
import '../domain/guardian_profile.dart';

/// Guardian profile — calm and uncluttered, from the "Cat-ch Mobile UI" design
/// (turn 7): identity, a warm 3-stat summary, a journey note, cloud account,
/// and privacy-first settings. Rank is grown by kindness, never combat
/// (docs/product/01-vision.md).
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
      body: SafeArea(
        bottom: false,
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErrorState(
            onRetry: () => ref.invalidate(guardianProfileProvider),
          ),
          data: _content,
        ),
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
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          _ProfileHeader(profile: p, onEdit: () => _editName(p.displayName)),
          const SizedBox(height: 16),
          _StatsCard(profile: p),
          const SizedBox(height: 16),
          _JourneyCard(text: _journeyText(p)),
          const SizedBox(height: 16),
          const _AccountCard(),
          const SizedBox(height: 16),
          const _SettingsCard(),
          const SizedBox(height: 16),
          Text(
            'Your map and photos are yours alone unless you share them.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  String _journeyText(GuardianProfile p) {
    if (p.catsCount == 0) {
      return 'Your journey is just beginning. Head out for a walk and say '
          'hello to your first fur-iend.';
    }
    final cats = p.catsCount == 1 ? 'one cat' : '${p.catsCount} cats';
    final places = p.placesExplored <= 1
        ? 'your neighbourhood'
        : '${p.placesExplored} corners of the map';
    return "You've befriended $cats across $places, sharing ${p.totalBond} "
        'moments of care along the way. Rank: ${p.rankLabel}.';
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

/// A warm surface card matching the design language (soft border + shadow).
class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: child,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});

  final GuardianProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.displayName ?? 'Guest Guardian';
    return Row(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.peach,
            border: Border.all(color: AppTheme.apricot, width: 3),
          ),
          child: const Icon(Icons.pets, size: 36, color: AppTheme.terracotta),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Guardian name',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _RankPill(label: profile.rankLabel),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets,
              size: 14,
              color: isLight ? const Color(0xFF6E8C66) : AppTheme.sage),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isLight ? const Color(0xFF2E3A2A) : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.profile});

  final GuardianProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget divider() => Container(width: 1, height: 40, color: theme.colorScheme.outline);
    return _SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(value: '${profile.catsCount}', label: 'cats met'),
          ),
          divider(),
          Expanded(
            child: _StatCell(
                value: '${profile.placesExplored}', label: 'places explored'),
          ),
          divider(),
          Expanded(
            child: _StatCell(value: '${profile.totalBond}', label: 'bond shared'),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(
            text: 'Your journey so far — ',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text),
        ]),
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingRow(
            chipColor: theme.colorScheme.primaryContainer,
            icon: Icons.shield_outlined,
            iconColor: AppTheme.terracotta,
            title: 'Privacy',
            subtitle: 'Location: neighbourhood only · never precise',
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          _SettingRow(
            chipColor: theme.colorScheme.surfaceContainerHigh,
            icon: Icons.tune,
            iconColor: theme.colorScheme.onSurfaceVariant,
            title: 'Permissions',
            subtitle: 'Manage camera & location access',
            onTap: () => openAppSettings(),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.chipColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final Color chipColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Cloud sync for grown-ups: back the CatDex up to an account, or show the
/// signed-in email with a way out. Watches auth state so it flips the instant
/// the guardian links, signs in, or signs out.
class _AccountCard extends ConsumerStatefulWidget {
  const _AccountCard();

  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    ref.invalidate(guardianProfileProvider);
    ref.invalidate(catsProvider);
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Signed out — back to a local guest 🐾'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the session changes (link / sign in / sign out).
    ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final auth = ref.read(authRepositoryProvider);
    final signedIn = auth.isCloudAccount;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(signedIn ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                signedIn ? 'Backed up to the cloud' : 'Back up to the cloud',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            signedIn
                ? 'Signed in as ${auth.email}. Your CatDex syncs to any device '
                    'you sign in on.'
                : 'Grown-ups can save their CatDex to the cloud and sync it '
                    'across devices. Your cats stay on this device until you do.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (signedIn)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _signOut,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outline),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Sign out'),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push(AppRoutes.account, extra: true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Create an account'),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => context.push(AppRoutes.account),
                child: const Text('I already have an account'),
              ),
            ),
          ],
        ],
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
