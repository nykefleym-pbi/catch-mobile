import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../social/domain/safe_play.dart';
import '../domain/age_bracket.dart';

/// Persisted key for the self-declared age band. Versioned so a future gate
/// change can re-ask without colliding with old values.
const _ageBracketKey = 'age_bracket_v1';

/// Holds the player's [AgeBracket], sourced from [SharedPreferences] so the
/// social gate can decide synchronously (no personal data — just a coarse band,
/// per ADR 0003's data-minimization). Setting it also mirrors the value to
/// `profiles.age_bracket` so server-side minor protections (the friends-only
/// showcase policy) have it too.
class AgeGateController extends Notifier<AgeBracket> {
  @override
  AgeBracket build() => AgeBracket.fromToken(
        ref.read(sharedPreferencesProvider).getString(_ageBracketKey),
      );

  /// Records the chosen band locally and mirrors it to the profile row.
  Future<void> set(AgeBracket bracket) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_ageBracketKey, bracket.token);
    state = bracket;
    unawaited(_mirrorToProfile(bracket));
  }

  Future<void> _mirrorToProfile(AgeBracket bracket) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client
          .from('profiles')
          .update({'age_bracket': bracket.token}).eq('id', userId);
    } catch (_) {
      // Best-effort: the local value is the source of truth for gating, and the
      // showcase policy simply stays conservative until the mirror succeeds.
    }
  }
}

final ageBracketProvider =
    NotifierProvider<AgeGateController, AgeBracket>(AgeGateController.new);

/// What the current player is allowed to do on social surfaces — the single
/// source of truth every Phase 3 screen gates on. Combines the age band with the
/// master [kSocialLive] switch for live trading/contests.
final socialCapabilitiesProvider = Provider<SocialCapabilities>((ref) {
  final bracket = ref.watch(ageBracketProvider);
  return SocialCapabilities.forBracket(bracket, socialLive: kSocialLive);
});
