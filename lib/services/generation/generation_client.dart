import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase/supabase_providers.dart';

/// A generated companion returned by the server-side pipeline.
class GeneratedCompanion {
  const GeneratedCompanion({
    required this.spriteUrl,
    required this.generationMeta,
  });

  /// CDN/storage URL of the transparent-background sprite.
  final String spriteUrl;

  /// Non-identifying descriptive attributes extracted during generation
  /// (coat colour, pattern, eye colour, tail shape, distinctive markings).
  final Map<String, dynamic> generationMeta;
}

/// Client-side contract for companion generation.
///
/// The client NEVER calls the image provider directly. It calls our
/// `generate-companion` Supabase Edge Function, which holds the provider key
/// and enforces auth, rate limits, cost caps, and moderation (ADR 0001,
/// docs/architecture/07-ai-pipeline.md). The raw photo is deleted server-side
/// once generation succeeds.
abstract interface class GenerationClient {
  Future<GeneratedCompanion> generate({
    required Uint8List acceptedImageBytes,
    required String captureId,
  });
}

/// Edge Function-backed implementation. Body is stubbed in Phase 0 — the wiring
/// and the "never call the provider from the client" boundary are what matter
/// here.
class EdgeFunctionGenerationClient implements GenerationClient {
  EdgeFunctionGenerationClient(this._ref);

  final Ref _ref;

  @override
  Future<GeneratedCompanion> generate({
    required Uint8List acceptedImageBytes,
    required String captureId,
  }) async {
    // Phase 1: invoke the Edge Function, e.g.
    //   final client = _ref.read(supabaseClientProvider);
    //   final res = await client.functions.invoke('generate-companion', body: {...});
    // For now, force callers to handle the not-yet-implemented state explicitly.
    _ref.read(supabaseClientProvider); // keep the dependency wired
    throw UnimplementedError(
      'generate-companion Edge Function is implemented in Phase 1',
    );
  }
}

final generationClientProvider = Provider<GenerationClient>((ref) {
  return EdgeFunctionGenerationClient(ref);
});
