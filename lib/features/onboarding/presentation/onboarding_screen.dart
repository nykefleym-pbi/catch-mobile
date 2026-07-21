import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../map/data/location_service.dart';
import '../../safety/data/age_gate.dart';
import '../../safety/domain/age_bracket.dart';
import '../data/onboarding_repository.dart';

/// The first-launch welcome + consent flow, built from the "Cat-ch Mobile UI"
/// design (turn 1: onboarding & consent — safety first, zero dark patterns).
///
/// Cozy pages — Welcome, a neutral age band, Location consent, Camera consent —
/// each with a real decline path. The consent steps make genuine permission
/// requests
/// (location via geolocator, camera via permission_handler) but always let the
/// guardian continue; declining just means a sample map / browse-first start.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 4;

  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    if (_page < _pageCount - 1) {
      unawaited(_controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      ));
    }
  }

  void _back() {
    if (_page > 0) {
      unawaited(_controller.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      ));
    }
  }

  Future<void> _shareLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(locationServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() => _busy = false);
    _advance();
  }

  Future<void> _finish({bool enableCamera = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (enableCamera) {
      await Permission.camera.request();
    }
    if (!mounted) return;
    // Persisting completion flips the router's onboarding gate, which redirects
    // us on to the map — no explicit navigation needed here.
    await ref.read(onboardingCompleteProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(page: _page, count: _pageCount, onBack: _back),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(onStart: _advance),
                  _AgePage(onDone: _advance),
                  _LocationPage(
                    busy: _busy,
                    onShare: _shareLocation,
                    onSkip: _advance,
                  ),
                  _CameraPage(
                    busy: _busy,
                    onEnable: () => _finish(enableCamera: true),
                    onSkip: () => _finish(),
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

/// Back chevron + progress dots. Hidden on the welcome page (which is the
/// intro, matching the design where the dots first appear on the consent steps).
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.page,
    required this.count,
    required this.onBack,
  });

  final int page;
  final int count;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (page == 0) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          _RoundChip(icon: Icons.chevron_left, onTap: onBack),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (i) {
                final filled = i <= page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: filled ? 22 : 16,
                  height: 8,
                  decoration: BoxDecoration(
                    color: filled ? theme.colorScheme.primary : theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// --- Page 1: Welcome ---------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      child: Column(
        children: [
          const Spacer(),
          const _Breathing(child: _LogoMark(width: 280)),
          const SizedBox(height: 26),
          Text(
            'Every cat has a story.\nEvery player can make a difference.',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.w500,
              fontSize: 19,
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'A cozy stroll. A surprise fur-iend around the corner. '
            'A collection that helps real cats.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          _PillButton(label: "Let's go meet some cats", onPressed: onStart),
          const SizedBox(height: 12),
          _PillButton(
            label: 'I already have an account',
            onPressed: () => context.push(AppRoutes.account),
            filled: false,
          ),
        ],
      ),
    );
  }
}

// --- Page 2: Age band + birthday month ---------------------------------------

/// A neutral age question with no defaults, no nudging, no "recommended" — it
/// just asks, so younger players get gentler settings when playing with others.
/// We also ask for a birthday *month* (only the month, and only if they want to
/// share it) so we can celebrate their special month later.
class _AgePage extends ConsumerStatefulWidget {
  const _AgePage({required this.onDone});

  /// Called once the player has confirmed their choice; advances the flow.
  final VoidCallback onDone;

  @override
  ConsumerState<_AgePage> createState() => _AgePageState();
}

class _AgePageState extends ConsumerState<_AgePage> {
  AgeBracket? _bracket;
  int? _month; // 1–12, or null if they'd rather not say.
  bool _saving = false;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Future<void> _confirm() async {
    final bracket = _bracket;
    if (bracket == null || _saving) return;
    setState(() => _saving = true);
    await ref.read(ageBracketProvider.notifier).set(bracket);
    if (_month != null) {
      await ref.read(birthMonthProvider.notifier).set(_month!);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _Breathing(child: _CatMark(size: 88))),
                const SizedBox(height: 20),
                Text(
                  'How old are you?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w600,
                    fontSize: 25,
                    height: 1.25,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This helps us keep playing with others safe and fun.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                _AgeOption(
                  label: 'Under 13',
                  selected: _bracket == AgeBracket.under13,
                  onTap: () => setState(() => _bracket = AgeBracket.under13),
                ),
                const SizedBox(height: 12),
                _AgeOption(
                  label: '13 to 17',
                  selected: _bracket == AgeBracket.teen,
                  onTap: () => setState(() => _bracket = AgeBracket.teen),
                ),
                const SizedBox(height: 12),
                _AgeOption(
                  label: '18 or older',
                  selected: _bracket == AgeBracket.adult,
                  onTap: () => setState(() => _bracket = AgeBracket.adult),
                ),
                const SizedBox(height: 28),
                Text(
                  "When's your birthday?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w600,
                    fontSize: 19,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Pick your month and we'll celebrate it with you. "
                  'You can skip this if you like.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      _MonthChip(
                        label: _monthNames[m - 1],
                        selected: _month == m,
                        // Tapping the chosen month again clears it (optional).
                        onTap: () => setState(
                          () => _month = _month == m ? null : m,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _PillButton(
            label: 'Continue',
            busy: _saving,
            // Neutral gate: no age is pre-selected, so Continue stays disabled
            // until the player answers the age question themselves.
            onPressed: _bracket == null || _saving ? null : _confirm,
          ),
        ),
      ],
    );
  }
}

/// A plain, equally-weighted age choice. Kept deliberately uniform so no option
/// is visually favoured over another; the only emphasis is the player's own pick.
class _AgeOption extends StatelessWidget {
  const _AgeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          side: BorderSide(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.fredoka(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small, tappable month pill for the optional birthday-month picker.
class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Page 3: Location consent ------------------------------------------------

class _LocationPage extends StatelessWidget {
  const _LocationPage({
    required this.busy,
    required this.onShare,
    required this.onSkip,
  });

  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return _ConsentLayout(
      hero: const _LocationHero(),
      title: 'Find cats around you',
      cards: [
        _InfoCard(
          chipColor: theme.colorScheme.primaryContainer,
          icon: Icons.location_on,
          iconColor: AppTheme.terracotta,
          text: const TextSpan(
            text: 'We use only your general area — not your exact location.',
          ),
        ),
        _InfoCard(
          chipColor: theme.colorScheme.secondaryContainer,
          icon: Icons.blur_on,
          iconColor: isLight ? const Color(0xFF6E8C66) : AppTheme.sage,
          text: const TextSpan(
            text: 'Cats appear in a nearby zone, never at a precise spot.',
          ),
        ),
        _InfoCard(
          chipColor: theme.colorScheme.surfaceContainerHigh,
          icon: Icons.tune,
          iconColor: theme.colorScheme.onSurfaceVariant,
          text: const TextSpan(
            text: 'You can change this anytime in Settings.',
          ),
        ),
      ],
      primaryLabel: 'Share my general area',
      onPrimary: onShare,
      secondaryLabel: 'Not now — show a sample map',
      onSecondary: onSkip,
      busy: busy,
    );
  }
}

class _LocationHero extends StatelessWidget {
  const _LocationHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      width: 210,
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -20,
            top: 22,
            child: _blob(isLight, 120, 76),
          ),
          Positioned(
            right: -24,
            bottom: -18,
            child: _blob(isLight, 130, 88),
          ),
          // The soft "cozy zone" spotlight — a fuzzy circle, not a pin.
          const _Breathing(
            minScale: 0.94,
            child: _CozyZone(),
          ),
        ],
      ),
    );
  }

  Widget _blob(bool isLight, double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFCBDCC5) : const Color(0xFF3A443A),
          borderRadius: BorderRadius.circular(44),
        ),
      );
}

class _CozyZone extends StatelessWidget {
  const _CozyZone();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.apricot.withValues(alpha: 0.30),
        border: Border.all(color: AppTheme.apricot, width: 2),
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.apricot,
          ),
        ),
      ),
    );
  }
}

// --- Page 4: Camera consent --------------------------------------------------

class _CameraPage extends StatelessWidget {
  const _CameraPage({
    required this.busy,
    required this.onEnable,
    required this.onSkip,
  });

  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return _ConsentLayout(
      hero: const _CameraHero(),
      title: 'Snap adorable cats',
      cards: [
        _InfoCard(
          chipColor: theme.colorScheme.secondaryContainer,
          icon: Icons.pets,
          iconColor: isLight ? const Color(0xFF6E8C66) : AppTheme.sage,
          text: const TextSpan(
            text: 'Use your camera to discover and collect real cats.',
          ),
        ),
        _InfoCard(
          chipColor: theme.colorScheme.primaryContainer,
          icon: Icons.smartphone,
          iconColor: AppTheme.terracotta,
          text: const TextSpan(
            text: 'Your photos stay on your device unless you choose to '
                'share them.',
          ),
        ),
        _InfoCard(
          chipColor: theme.colorScheme.surfaceContainerHigh,
          icon: Icons.favorite,
          iconColor: theme.colorScheme.onSurfaceVariant,
          text: const TextSpan(
            text: "Please respect people's privacy and ask before taking "
                'their photo.',
          ),
        ),
      ],
      extra: const _GuardianNote(),
      primaryLabel: 'Enable camera',
      onPrimary: onEnable,
      secondaryLabel: 'Maybe later — browse first',
      onSecondary: onSkip,
      busy: busy,
    );
  }
}

class _CameraHero extends StatelessWidget {
  const _CameraHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 210,
      height: 150,
      child: Center(
        child: _Breathing(
          minScale: 0.96,
          child: Container(
            width: 120,
            height: 92,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.terracotta, width: 2.5),
            ),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.terracotta, width: 2.5),
                ),
                child: const Center(
                  child: Icon(Icons.pets, size: 20, color: AppTheme.apricot),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuardianNote extends StatelessWidget {
  const _GuardianNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.apricot.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.apricot,
            ),
            child: const Icon(Icons.pets, size: 20, color: Color(0xFFFFF7EF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              const TextSpan(children: [
                TextSpan(
                  text: 'Under 13? ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: 'Ask a parent or guardian to help you get started.',
                ),
              ]),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Shared consent scaffolding ----------------------------------------------

/// The common layout for a consent step: a scrollable hero + title + info
/// cards, with the primary/secondary decision pinned at the bottom.
class _ConsentLayout extends StatelessWidget {
  const _ConsentLayout({
    required this.hero,
    required this.title,
    required this.cards,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.busy,
    this.extra,
  });

  final Widget hero;
  final String title;
  final List<Widget> cards;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final bool busy;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
            child: Column(
              children: [
                Center(child: hero),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w600,
                    fontSize: 25,
                    height: 1.25,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 18),
                for (final card in cards) ...[
                  card,
                  const SizedBox(height: 12),
                ],
                if (extra != null) extra!,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              _PillButton(
                label: primaryLabel,
                onPressed: busy ? null : onPrimary,
                busy: busy,
              ),
              const SizedBox(height: 12),
              _PillButton(
                label: secondaryLabel,
                onPressed: busy ? null : onSecondary,
                filled: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One consent bullet: a soft surface card holding a rounded colour chip + a
/// rich text explanation.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.chipColor,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final Color chipColor;
  final IconData icon;
  final Color iconColor;
  final InlineSpan text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 56-tall pill button in the design's two flavours: filled apricot primary
/// and bordered surface secondary.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
    final child = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Text(label);

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: shape,
            textStyle:
                GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 17),
          ),
          child: child,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: shape,
          foregroundColor: theme.colorScheme.onSurface,
          backgroundColor: theme.colorScheme.surface,
          side: BorderSide(color: theme.colorScheme.outline, width: 1.5),
          textStyle:
              GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        child: child,
      ),
    );
  }
}

/// The Cat-ch mark: a peach circle cradling a simple terracotta paw, used as the
/// welcome hero in place of a bundled logo asset.
class _CatMark extends StatelessWidget {
  const _CatMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.peach,
      ),
      child: Icon(Icons.pets, size: size * 0.42, color: AppTheme.terracotta),
    );
  }
}

/// The Cat-ch wordmark logo. Renders the bundled brand art, falling back to the
/// simple paw mark if the asset can't be loaded (e.g. in a bare test harness) so
/// onboarding never fails on a missing image.
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/logo.png',
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => const _CatMark(size: 132),
    );
  }
}

/// A gentle, endless breathing scale — the cozy motion the design uses on hero
/// art. Defaults match the reveal card's 0.96↔1.04 pulse.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.child, this.minScale = 0.96});

  final Widget child;
  final double minScale;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: widget.minScale, end: 1.04).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
