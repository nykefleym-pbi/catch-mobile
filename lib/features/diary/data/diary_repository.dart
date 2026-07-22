import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase/supabase_providers.dart';
import '../../onboarding/data/onboarding_repository.dart'
    show sharedPreferencesProvider;
import '../../safety/data/age_gate.dart';
import '../domain/diary_entry.dart';

/// Reads and writes a cat's private diary.
///
/// Minor handling (ADR 0003 / 0005): for minors (or when there is no session)
/// diary notes are kept **on-device only** and never sent to the server; adults
/// sync to the owner-only `cat_diary_entries` table (RLS scopes every row to the
/// signed-in user). This makes data-minimisation structural, not incidental.
class DiaryRepository {
  DiaryRepository(this._ref);

  final Ref _ref;

  bool get _isMinor => _ref.read(ageBracketProvider).isMinor;

  String _localKey(String catId) => 'diary_local_$catId';

  Future<List<DiaryEntry>> entriesFor(String catId) async {
    if (_isMinor) return _readLocal(catId);
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return _readLocal(catId);
    final rows = await client
        .from('cat_diary_entries')
        .select('id, cat_id, kind, body, location_label, created_at')
        .eq('cat_id', catId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => DiaryEntry.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Adds a short note. Minors (and sessionless clients) write on-device only.
  Future<void> addNote(String catId, String body, {String? locationLabel}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final entry = DiaryEntry(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      catId: catId,
      kind: DiaryKind.note,
      body: trimmed,
      locationLabel: locationLabel,
      createdAt: DateTime.now(),
    );

    if (_isMinor) return _addLocal(entry);
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return _addLocal(entry);
    await client.from('cat_diary_entries').insert(entry.toRow(userId));
  }

  // --- On-device store (minor mode / no session) ----------------------------

  List<DiaryEntry> _readLocal(String catId) {
    final raw = _ref.read(sharedPreferencesProvider).getString(_localKey(catId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => DiaryEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _addLocal(DiaryEntry entry) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final next = [entry, ..._readLocal(entry.catId)];
    await prefs.setString(
      _localKey(entry.catId),
      jsonEncode([for (final e in next) e.toLocalJson()]),
    );
  }
}

final diaryRepositoryProvider =
    Provider<DiaryRepository>((ref) => DiaryRepository(ref));

/// The diary for a given cat. Auto-disposes; invalidate after adding a note.
final catDiaryProvider = FutureProvider.autoDispose
    .family<List<DiaryEntry>, String>((ref, catId) async {
  return ref.read(diaryRepositoryProvider).entriesFor(catId);
});
