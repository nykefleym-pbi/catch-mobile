import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../catdex/data/cats_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../profile/data/guardian_repository.dart';
import '../data/auth_repository.dart';

enum _Mode { signIn, createAccount }

/// Cloud account for grown-ups — back up the CatDex or sign in on a new device.
/// Presented over the app; on success it refreshes the guardian's data and
/// bows out (completing onboarding if the guardian reached it from the welcome
/// flow).
class AccountScreen extends ConsumerStatefulWidget {
  /// Named constructors keep the router call-sites readable. The flag stays a
  /// plain bool so no private type leaks into this public widget's API.
  const AccountScreen.signIn({super.key}) : startInCreate = false;
  const AccountScreen.create({super.key}) : startInCreate = true;

  final bool startInCreate;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late _Mode _mode =
      widget.startInCreate ? _Mode.createAccount : _Mode.signIn;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  bool get _isCreate => _mode == _Mode.createAccount;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _mode = _isCreate ? _Mode.signIn : _Mode.createAccount;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Passwords need at least 6 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = ref.read(authRepositoryProvider);
    try {
      if (_isCreate) {
        await auth.linkEmail(email: email, password: password);
      } else {
        await auth.signIn(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
      return;
    }

    if (!mounted) return;

    // Fresh account/session — reload everything the guardian sees.
    ref.invalidate(guardianProfileProvider);
    ref.invalidate(catsProvider);

    // A guardian who reached this from the welcome flow doesn't need to walk
    // through it — mark onboarding done so they land straight in the app.
    final wasOnboarded = ref.read(onboardingCompleteProvider);
    if (!wasOnboarded) {
      await ref.read(onboardingCompleteProvider.notifier).complete();
    }
    if (!mounted) return;

    // Capture the messenger before navigating so the confirmation still shows
    // on the destination screen. Creating an account may need email
    // confirmation, so word that path honestly rather than implying success.
    final messenger = ScaffoldMessenger.of(context);
    if (!wasOnboarded) {
      // The account route is exempt from the onboarding gate, so move on
      // explicitly rather than relying on a redirect.
      context.go(AppRoutes.map);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.map);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_isCreate
              ? 'Almost there — check your email to confirm your account ✨'
              : 'Signed in — your cats are syncing 🐾'),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!Env.hasSupabase) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              "Cloud sync isn't available in this build.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Back up to the cloud' : 'Welcome back'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.peach,
                ),
                child: const Icon(Icons.cloud_outlined,
                    size: 44, color: AppTheme.terracotta),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isCreate ? 'Keep your cats safe' : 'Ready when you are',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _isCreate
                  ? 'Grown-ups can back up their CatDex to the cloud, so your '
                      'companions come with you to any device.'
                  : 'Sign in to bring your synced CatDex to this device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _Field(
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              icon: Icons.mail_outline,
            ),
            const SizedBox(height: 14),
            _Field(
              controller: _password,
              label: 'Password',
              hint: 'At least 6 characters',
              obscure: _obscure,
              icon: Icons.lock_outline,
              trailing: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: _obscure ? 'Show password' : 'Hide password',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _Banner(
                icon: Icons.error_outline,
                color: theme.colorScheme.error,
                text: _error!,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  textStyle: GoogleFonts.fredoka(
                      fontWeight: FontWeight.w600, fontSize: 17),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(_isCreate ? 'Create account' : 'Sign in'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _switchMode,
              child: Text(_isCreate
                  ? 'I already have an account'
                  : "New here? Create an account"),
            ),
            const SizedBox(height: 8),
            Text(
              'Accounts are meant for grown-ups. Your email is only used to '
              'sign you in and keep your CatDex backed up.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded, filled text field matching the Cat-ch surface language.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        suffixIcon: trailing,
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
