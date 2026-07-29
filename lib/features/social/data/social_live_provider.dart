import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../domain/safe_play.dart';
import '../domain/social_launch_gate.dart';

/// The device's current region as an ISO 3166-1 alpha-2 code, used *only* to
/// place the player in or out of a cleared launch market.
///
/// Sourced from the platform locale as an honest initial proxy: the app never
/// persists precise location (ADR 0001 / data model), so the coarse storefront /
/// locale region is the strongest signal available here, and it can be hardened
/// later (e.g. a store-provided storefront region) without changing the gate.
/// Exposed as a provider so it can be overridden in tests or for a forced
/// single-market build.
final deviceRegionProvider = Provider<String?>((ref) {
  final country = ui.PlatformDispatcher.instance.locale.countryCode;
  return (country == null || country.isEmpty) ? null : country.toUpperCase();
});

/// The **effective** live-social signal: the master [kSocialLive] switch AND the
/// launch-market geo-gate ([SocialLaunchGate]). Capability and UI decisions
/// compose on this rather than the raw const, so a market that has not cleared
/// its store/privacy review never sees live trading or contests even when the
/// master switch is on.
///
/// The repositories keep gating on the raw `kSocialLive` const directly — that
/// compile-time short-circuit is the hard network backstop; this provider is the
/// additional per-market lock at the capability layer.
final socialLiveProvider = Provider<bool>((ref) {
  return SocialLaunchGate.isLive(
    socialLive: kSocialLive,
    launchMarkets: Env.launchMarkets,
    region: ref.watch(deviceRegionProvider),
  );
});
