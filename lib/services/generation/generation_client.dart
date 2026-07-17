import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/supabase_providers.dart';
import '../../features/catdex/domain/cat.dart';

/// Raised when companion generation fails. [message] is safe to show to the
/// player; [code] is the machine-readable reason from the Edge Function.
class GenerationException implements Exception {
  const GenerationException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'GenerationException($code): $message';
}

/// Client-side contract for companion generation.
///
/// The client NEVER calls the image provider directly. It calls our
/// `generate-companion` Supabase Edge Function, which holds the provider key and
/// enforces auth, the daily cap, and moderation (ADR 0001,
/// docs/architecture/07-ai-pipeline.md). The raw photo is sent inline and is
/// never persisted server-side.
abstract interface class GenerationClient {
  Future<Cat> generate({
    required Uint8List imageBytes,
    String mimeType,
    Map<String, dynamic>? detection,
    double? lat,
    double? lng,
  });
}

/// Edge Function-backed implementation.
class EdgeFunctionGenerationClient implements GenerationClient {
  EdgeFunctionGenerationClient(this._ref);

  final Ref _ref;

  @override
  Future<Cat> generate({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    Map<String, dynamic>? detection,
    double? lat,
    double? lng,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    try {
      final res = await client.functions.invoke(
        'generate-companion',
        body: {
          'imageBase64': base64Encode(imageBytes),
          'mimeType': mimeType,
          if (detection != null) 'detection': detection,
          if (lat != null && lng != null) 'lat': lat,
          if (lat != null && lng != null) 'lng': lng,
        },
      );
      final data = res.data;
      if (data is! Map || data['cat'] is! Map) {
        throw const GenerationException(
          'We couldn\'t bring them to life just now. Please try again.',
        );
      }
      return Cat.fromMap(Map<String, dynamic>.from(data['cat'] as Map));
    } on FunctionException catch (error) {
      throw GenerationException(
        _friendlyMessage(error),
        code: _codeFrom(error.details),
      );
    }
  }

  String? _codeFrom(dynamic details) {
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return null;
  }

  String _friendlyMessage(FunctionException error) {
    final code = _codeFrom(error.details);
    switch (code) {
      case 'daily_cap_reached':
        return 'You\'ve caught a lot of cats today! Come back tomorrow for more.';
      case 'generation_unconfigured':
        return 'Companion magic isn\'t switched on yet. Try again soon.';
      case 'unauthorized':
        return 'Please reopen the app and try catching again.';
      case 'generation_failed':
        return 'The magic fizzled this time — give it another try.';
      default:
        return 'Something went wrong bringing them to life. Please try again.';
    }
  }
}

final generationClientProvider = Provider<GenerationClient>((ref) {
  return EdgeFunctionGenerationClient(ref);
});
