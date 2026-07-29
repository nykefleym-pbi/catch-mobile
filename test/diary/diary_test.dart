import 'package:catch_mobile/features/diary/data/diary_repository.dart';
import 'package:catch_mobile/features/diary/domain/diary_entry.dart';
import 'package:catch_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:catch_mobile/features/safety/data/age_gate.dart';
import 'package:catch_mobile/features/safety/domain/age_bracket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MinorGate extends AgeGateController {
  @override
  AgeBracket build() => AgeBracket.under13;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiaryEntry serialization', () {
    test('toRow never carries coordinates — only a coarse label', () {
      final row = DiaryEntry(
        id: 'x',
        catId: 'c1',
        kind: DiaryKind.note,
        createdAt: DateTime.utc(2026, 7, 22),
        body: 'hello',
        locationLabel: 'Downtown',
      ).toRow('user1');
      expect(row.keys, isNot(contains('geo_lat')));
      expect(row.keys, isNot(contains('geo_lng')));
      expect(row.keys, isNot(contains('lat')));
      expect(row.keys, isNot(contains('lng')));
      expect(row['cat_id'], 'c1');
      expect(row['profile_id'], 'user1');
      expect(row['kind'], 'note');
      expect(row['location_label'], 'Downtown');
    });

    test('fromMap round-trips', () {
      final e = DiaryEntry.fromMap({
        'id': '1',
        'cat_id': 'c1',
        'kind': 'milestone',
        'body': 'reached level 2',
        'location_label': null,
        'created_at': '2026-07-22T00:00:00.000Z',
      });
      expect(e.kind, DiaryKind.milestone);
      expect(e.body, 'reached level 2');
      expect(e.locationLabel, isNull);
    });
  });

  test('minor mode keeps diary notes on-device (never hits the server)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ageBracketProvider.overrideWith(_MinorGate.new),
    ]);
    addTearDown(container.dispose);

    final repo = container.read(diaryRepositoryProvider);
    expect(await repo.entriesFor('cat1'), isEmpty);

    await repo.addNote('cat1', '  first memory ');
    final entries = await repo.entriesFor('cat1');
    expect(entries.length, 1);
    expect(entries.first.body, 'first memory'); // trimmed
    expect(entries.first.kind, DiaryKind.note);
    // Persisted to the local store, not the server.
    expect(prefs.getString('diary_local_cat1'), isNotNull);
  });
}
