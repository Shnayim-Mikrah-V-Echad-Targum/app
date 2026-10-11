import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/community/data/backend.dart';
import 'package:shnayim_mikra/features/community/data/community_providers.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/notes/domain/annotations.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_merge.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/backup.dart';

const _genesis3_22 = BookVerse('Genesis', VerseRef(3, 22));
const _genesis1_1 = BookVerse('Genesis', VerseRef(1, 1));
const _exodus3_14 = BookVerse('Exodus', VerseRef(3, 14));
const _me = CommunityUser(id: 'me', email: 'me@example.com');

/// One account's backup in memory, as the server keeps it: re-encoded, so
/// that nothing is shared with the device that saved it.
class _Cloud extends Fake implements ForumRepository {
  Map<String, dynamic>? backup;

  @override
  bool get isDemo => false;

  @override
  CommunityUser? get currentUser => _me;

  @override
  Stream<CommunityUser?> get userChanges => const Stream.empty();

  @override
  Future<Profile?> myProfile() async => Profile(id: _me.id, displayName: 'Reader');

  @override
  Future<Map<String, dynamic>?> loadProgress() async =>
      backup == null ? null : jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;

  @override
  Future<void> saveProgress(Map<String, dynamic> data) async => backup = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
}

/// A device with backup on, whose storage holds [stored]: one at a time, as
/// each has storage of its own.
Future<ProviderContainer> _device(_Cloud cloud, {Map<String, Object> stored = const {}}) async {
  SharedPreferences.setMockInitialValues({
    SettingsController.storageKey: jsonEncode(const AppSettings(onboardingComplete: true, cloudSync: true).toJson()),
    ...stored,
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    backendProvider.overrideWithValue(Backend(cloud)),
  ]);
  c.listen(progressSyncProvider, (_, _) {});
  // Signed in, and the sync that starts as backup does run.
  await pumpEventQueue();
  return c;
}

/// What [c]'s device has stored, for it to start from again later.
Map<String, Object> _storage(ProviderContainer c) {
  final prefs = c.read(sharedPreferencesProvider);
  return {for (final k in prefs.getKeys()) k: prefs.get(k)!};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int clock;
  setUp(() {
    clock = 1000;
    ProgressClock.nowMs = () => clock;
  });
  tearDown(() => ProgressClock.nowMs = () => DateTime.now().millisecondsSinceEpoch);

  group('an annotation', () {
    test('is stored as the verse, its bookmark, its note and when each changed', () {
      final a = Annotations.empty.withBookmark(_genesis3_22, true).withNote(_genesis3_22, '  Like one of us?  ');
      expect(a.toJson(), {
        'Genesis 3:22': {'b': true, 'n': 'Like one of us?', 'bu': 1000, 'nu': 1001, 'u': 1001},
      });
      expect(Annotations.fromJson(jsonDecode(jsonEncode(a.toJson()))), a);
      expect(a[_genesis3_22]!.bookmarked, isTrue);
      expect(a[_genesis3_22]!.note, 'Like one of us?', reason: 'trimmed');
      expect(a[_genesis1_1], isNull);
    });

    test('removed, leaves a tombstone with the time of the removal', () {
      var a = Annotations.empty.withBookmark(_genesis3_22, true);
      clock = 2000;
      a = a.withBookmark(_genesis3_22, false);
      expect(a.toJson(), {
        'Genesis 3:22': {'b': false, 'n': null, 'bu': 2000, 'nu': 0, 'u': 2000},
      }, reason: 'the note, never written, keeps its time');
      expect(a[_genesis3_22], isNull);
      expect(a.entries.values.every((e) => e.isRemoved), isTrue, reason: 'only a tombstone');
      expect(a.inTorah, isEmpty);

      // A note emptied deletes it too; the bookmark beside it stays.
      a = a.withBookmark(_genesis1_1, true).withNote(_genesis1_1, 'Bereshit');
      clock = 3000;
      a = a.withNote(_genesis1_1, '   ');
      expect(a.toJson()['Genesis 1:1'], {'b': true, 'n': null, 'bu': 2000, 'nu': 3000, 'u': 3000});
    });

    test('changes nothing where nothing changes', () {
      final a = Annotations.empty.withNote(_genesis3_22, 'A thought');
      expect(identical(a.withNote(_genesis3_22, ' A thought '), a), isTrue);
      expect(identical(a.withBookmark(_genesis3_22, false), a), isTrue);
      expect(identical(Annotations.empty.withNote(_genesis1_1, ''), Annotations.empty), isTrue);
    });

    test('changed, outranks what it replaces even on a clock running behind', () {
      final elsewhere = Annotations.fromJson({
        'Genesis 3:22': {'b': true, 'n': 'From a phone ahead of time', 'u': 50000},
      });
      // This device's clock reads 1000.
      final here = elsewhere.withNote(_genesis3_22, null);
      expect(here.entries['Genesis 3:22']!.noteAt, 50001);
      expect(here.entries['Genesis 3:22']!.updatedAt, 50001);
      expect(Annotations.merge(elsewhere, here)[_genesis3_22]!.note, isNull);
    });

    test('changed, is later than both its times, for the versions that compare only the later', () {
      final elsewhere = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': 'From a phone ahead of time', 'bu': 10, 'nu': 50000, 'u': 50000},
      });
      // A bookmark changes the bookmark's time alone, but stamps it later than
      // the note's, so that `u` rises: an older version sees the change as
      // the later one.
      final here = elsewhere.withBookmark(_genesis3_22, true);
      expect(here.toJson()['Genesis 3:22'],
          {'b': true, 'n': 'From a phone ahead of time', 'bu': 50001, 'nu': 50000, 'u': 50001});
    });

    test('lists the Torah\'s verses in order, and those of a parsha', () {
      final a = Annotations.empty
          .withBookmark(_exodus3_14, true)
          .withNote(const BookVerse('Genesis', VerseRef(12, 1)), 'Lech lecha')
          .withBookmark(_genesis3_22, true)
          .withBookmark(const BookVerse('I Samuel', VerseRef(20, 18)), true)
          .withBookmark(_genesis1_1, true);
      expect([for (final (v, _) in a.inTorah) '$v'], ['Genesis 1:1', 'Genesis 3:22', 'Genesis 12:1', 'Exodus 3:14'],
          reason: 'a verse of the Prophets is kept, not listed');
      final bereshit = VerseRange('Genesis', const VerseRef(1, 1), const VerseRef(6, 8));
      expect([for (final (v, _) in a.within(bereshit)) '$v'], ['Genesis 1:1', 'Genesis 3:22']);
    });

    test('keeps what it can\'t read, and what a newer version stored with it', () {
      final json = {
        'Genesis 3:22': {'b': true, 'n': 'Kept', 'u': 5, 'c': 'gold'},
        'Genesis 1:1': {'b': 'yes', 'u': 6},
        'Genesis 1:2': 'not an annotation',
      };
      final a = Annotations.fromJson(json);
      expect(a.entries.keys, ['Genesis 3:22']);
      expect(a.unknown.keys, unorderedEquals(['Genesis 1:1', 'Genesis 1:2']));
      expect(a.toJson(), {
        ...json,
        'Genesis 3:22': {'b': true, 'n': 'Kept', 'bu': 5, 'nu': 5, 'u': 5, 'c': 'gold'},
      }, reason: 'written back exactly, with the times of its own that an older version\'s lacked');
      // Changed here, a newer version's field stays...
      expect(
        a.withBookmark(_genesis3_22, false).toJson()['Genesis 3:22'],
        {'b': false, 'n': 'Kept', 'bu': 1000, 'nu': 5, 'u': 1000, 'c': 'gold'},
      );
      // ...until nothing is left on the verse.
      expect(
        a.withBookmark(_genesis3_22, false).withNote(_genesis3_22, null).toJson()['Genesis 3:22'],
        {'b': false, 'n': null, 'bu': 1000, 'nu': 1001, 'u': 1001},
      );
      // A change here replaces what couldn't be read.
      expect(a.withBookmark(_genesis1_1, true).unknown.keys, ['Genesis 1:2']);
      expect(Annotations.fromJson('nonsense'), Annotations.empty);
      expect(Annotations.fromJson(null), Annotations.empty);
    });

    test('stored by an older version, or changed by one since, takes its one time for both', () {
      final old = Annotation.tryFromJson({'b': true, 'n': 'Kept', 'u': 7})!;
      expect((old.bookmarkAt, old.noteAt), (7, 7));

      // Stored here, then changed by an older version, which deleted the note,
      // stamped `u` anew and kept the times it couldn't read as they were.
      final changed = Annotations.fromJson({
        'Genesis 3:22': {'b': true, 'n': null, 'bu': 10, 'nu': 20, 'u': 30},
      });
      final e = changed.entries['Genesis 3:22']!;
      expect((e.bookmarkAt, e.noteAt), (30, 30));
      expect(e.extra, isEmpty, reason: 'the stale times are not kept');
      // So the deletion outranks the note it deleted, wherever that still is.
      final unchanged = Annotations.fromJson({
        'Genesis 3:22': {'b': true, 'n': 'Still here', 'bu': 10, 'nu': 20, 'u': 20},
      });
      expect(Annotations.merge(changed, unchanged)[_genesis3_22]!.note, isNull);
      expect(Annotations.merge(unchanged, changed)[_genesis3_22]!.note, isNull);

      // Times that can't be read, or of which `u` isn't the later, aren't used.
      for (final (bu, nu) in [(null, 30), ('30', 30), (-1, 30), (30, 40), (5, 5)]) {
        final a = Annotation.tryFromJson({'b': true, 'n': null, 'bu': bu, 'nu': nu, 'u': 30})!;
        expect((a.bookmarkAt, a.noteAt), (30, 30), reason: '$bu, $nu');
      }
      final a = Annotation.tryFromJson({'b': true, 'n': null, 'bu': 30, 'nu': 4, 'u': 30})!;
      expect((a.bookmarkAt, a.noteAt), (30, 4));
    });
  });

  group('merging', () {
    final older = Annotations.fromJson({
      'Genesis 3:22': {'b': true, 'n': 'Older', 'u': 10},
    });
    final newer = Annotations.fromJson({
      'Genesis 3:22': {'b': false, 'n': 'Newer', 'u': 20},
    });
    final deleted = Annotations.fromJson({
      'Genesis 3:22': {'b': false, 'n': null, 'u': 30},
    });

    test('keeps the later change to each verse', () {
      final elsewhere = Annotations.fromJson({
        'Genesis 1:1': {'b': true, 'n': null, 'u': 5},
      });
      final m = Annotations.merge(Annotations.merge(older, newer), elsewhere);
      expect(m[_genesis3_22]!.note, 'Newer');
      expect(m[_genesis3_22]!.bookmarked, isFalse);
      expect(m[_genesis1_1]!.bookmarked, isTrue);
    });

    test('lets a deletion win over the note it deleted, wherever the note still is', () {
      expect(Annotations.merge(older, deleted)[_genesis3_22], isNull);
      expect(Annotations.merge(deleted, older)[_genesis3_22], isNull);
      expect(Annotations.merge(deleted, older).entries['Genesis 3:22']!.isRemoved, isTrue, reason: 'the tombstone stays');
      // A note written again after the deletion comes back.
      final again = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': 'Again', 'u': 40},
      });
      expect(Annotations.merge(deleted, again)[_genesis3_22]!.note, 'Again');
    });

    test('keeps a bookmark made on one device and a note written on another, either way round', () {
      for (final before in [
        Annotations.empty,
        Annotations.fromJson({
          'Genesis 3:22': {'b': false, 'n': 'A thought', 'u': 10},
        }),
      ]) {
        // The tablet writes the note, and the phone, before they sync,
        // bookmarks the verse: the later change, but to the bookmark alone.
        clock = 1000;
        final tablet = before.withNote(_genesis3_22, 'A better thought');
        clock = 2000;
        final phone = before.withBookmark(_genesis3_22, true);
        for (final m in [Annotations.merge(phone, tablet), Annotations.merge(tablet, phone)]) {
          expect(m[_genesis3_22]!.bookmarked, isTrue);
          expect(m[_genesis3_22]!.note, 'A better thought');
          expect(m.entries['Genesis 3:22']!.updatedAt, 2000);
        }
      }
    });

    test('lets a note deleted after a bookmark made elsewhere go, and the bookmark stay', () {
      final before = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': 'A thought', 'u': 10},
      });
      clock = 1000;
      final phone = before.withBookmark(_genesis3_22, true);
      clock = 2000;
      final tablet = before.withNote(_genesis3_22, null);
      expect(tablet.entries['Genesis 3:22']!.isRemoved, isTrue, reason: 'nothing is left there');
      for (final m in [Annotations.merge(phone, tablet), Annotations.merge(tablet, phone)]) {
        expect(m[_genesis3_22]!.bookmarked, isTrue);
        expect(m[_genesis3_22]!.note, isNull);
      }

      // And the reverse: a bookmark taken away leaves a note written since
      // elsewhere.
      final marked = Annotations.empty.withBookmark(_genesis1_1, true);
      clock = 3000;
      final noted = marked.withNote(_genesis1_1, 'In the beginning');
      clock = 4000;
      final unmarked = marked.withBookmark(_genesis1_1, false);
      final m = Annotations.merge(unmarked, noted);
      expect((m[_genesis1_1]!.bookmarked, m[_genesis1_1]!.note), (false, 'In the beginning'));
    });

    test('lets a removal win a tie, and settles any other tie the same way either way round', () {
      final sameTime = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': null, 'u': 10},
      });
      expect(Annotations.merge(older, sameTime)[_genesis3_22], isNull);
      expect(Annotations.merge(sameTime, older)[_genesis3_22], isNull);
      final other = Annotations.fromJson({
        'Genesis 3:22': {'b': true, 'n': 'Other', 'u': 10},
      });
      expect(Annotations.merge(older, other), Annotations.merge(other, older));
    });

    test('is commutative, associative and idempotent', () {
      final sides = [
        Annotations.empty,
        older,
        newer,
        deleted,
        Annotations.fromJson({
          'Genesis 3:22': {'b': true, 'n': 'Tie', 'u': 20},
          'Exodus 3:14': {'b': true, 'n': null, 'u': 3},
          'Genesis 1:1': 'unreadable here',
        }),
        Annotations.fromJson({
          'Genesis 1:1': {'b': false, 'n': 'Read', 'u': 1},
          'Exodus 3:14': {'b': false, 'n': null, 'u': 3},
        }),
        Annotations.fromJson({'Genesis 1:1': 'unreadable there'}),
        // Each field changed at a time of its own, ties among them included.
        Annotations.fromJson({
          'Genesis 3:22': {'b': true, 'n': null, 'bu': 25, 'nu': 5, 'u': 25},
          'Exodus 3:14': {'b': true, 'n': 'Ehyeh', 'bu': 3, 'nu': 4, 'u': 4},
        }),
        Annotations.fromJson({
          'Genesis 3:22': {'b': false, 'n': 'Later', 'bu': 5, 'nu': 25, 'u': 25, 'c': 'gold'},
          'Exodus 3:14': {'b': false, 'n': null, 'bu': 4, 'nu': 3, 'u': 4},
        }),
        Annotations.fromJson({
          'Genesis 3:22': {'b': false, 'n': null, 'bu': 25, 'nu': 15, 'u': 25, 'c': 'silver'},
        }),
        // Changed by an older version since it was stored here.
        Annotations.fromJson({
          'Genesis 3:22': {'b': true, 'n': 'Old', 'bu': 5, 'nu': 25, 'u': 26},
        }),
        // Three whose newer version's fields would depend on the order merged
        // in, were the copy that kept them chosen by whether it was removed.
        Annotations.fromJson({
          'Genesis 2:3': {'b': true, 'n': null, 'bu': 10, 'nu': 5, 'u': 10, 'c': 'x'},
        }),
        Annotations.fromJson({
          'Genesis 2:3': {'b': false, 'n': null, 'bu': 10, 'nu': 3, 'u': 10, 'c': 'y'},
        }),
        Annotations.fromJson({
          'Genesis 2:3': {'b': false, 'n': 'Hi', 'bu': 2, 'nu': 10, 'u': 10, 'c': 'z'},
        }),
      ];
      for (final a in sides) {
        expect(Annotations.merge(a, a), a);
        for (final b in sides) {
          expect(Annotations.merge(a, b), Annotations.merge(b, a));
          for (final c in sides) {
            expect(
              Annotations.merge(Annotations.merge(a, b), c),
              Annotations.merge(a, Annotations.merge(b, c)),
            );
          }
        }
      }
    });

    test('keeps what neither side can read, unless one side can', () {
      final readable = Annotations.fromJson({
        'Genesis 1:1': {'b': true, 'n': null, 'u': 1},
      });
      final unreadable = Annotations.fromJson({'Genesis 1:1': 'from a newer version', 'Genesis 1:2': 'too'});
      final m = Annotations.merge(unreadable, readable);
      expect(m[_genesis1_1]!.bookmarked, isTrue);
      expect(m.unknown, {'Genesis 1:2': 'too'});
    });
  });

  group('restoring a backup', () {
    test('brings back a note deleted since, later than the deletion, so that a sync keeps it', () {
      final backedUp = Annotations.empty.withNote(_genesis3_22, 'For Shabbat');
      clock = 2000;
      final deleted = backedUp.withNote(_genesis3_22, null);
      clock = 3000;
      final restored = deleted.restoring(backedUp);
      expect(restored[_genesis3_22]!.note, 'For Shabbat');
      expect(restored.entries['Genesis 3:22']!.noteAt, 3000);
      // The cloud, which has the deletion, doesn't take it away again.
      expect(Annotations.merge(deleted, restored)[_genesis3_22]!.note, 'For Shabbat');
      expect(Annotations.merge(restored, deleted)[_genesis3_22]!.note, 'For Shabbat');

      // Even on a clock running behind the one that stamped the deletion.
      final aheadOfTime = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': null, 'u': 50000},
      });
      expect(aheadOfTime.restoring(backedUp).entries['Genesis 3:22']!.noteAt, 50001);
    });

    test('brings back a note deleted since beside the bookmark kept, and a bookmark taken away', () {
      final backedUp = Annotations.empty.withBookmark(_genesis3_22, true).withNote(_genesis3_22, 'Why?');
      clock = 2000;
      final noteDeleted = backedUp.withNote(_genesis3_22, null);
      clock = 3000;
      var restored = noteDeleted.restoring(backedUp);
      expect((restored[_genesis3_22]!.bookmarked, restored[_genesis3_22]!.note), (true, 'Why?'));
      final e = restored.entries['Genesis 3:22']!;
      expect((e.bookmarkAt, e.noteAt), (1000, 3000), reason: 'the bookmark, kept here, as it was');

      final unmarked = backedUp.withBookmark(_genesis3_22, false);
      clock = 4000;
      restored = unmarked.restoring(backedUp);
      expect((restored[_genesis3_22]!.bookmarked, restored[_genesis3_22]!.note), (true, 'Why?'));
      expect(restored.entries['Genesis 3:22']!.bookmarkAt, 4000);
    });

    test('keeps a note changed since, and takes one the backup holds a later change of', () {
      final backedUp = Annotations.empty.withNote(_genesis3_22, 'First thought');
      clock = 2000;
      final edited = backedUp.withNote(_genesis3_22, 'Second thought');
      clock = 3000;
      expect(edited.restoring(backedUp), edited, reason: 'nothing changes');

      // A backup from another device, made after a change there.
      final elsewhere = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': 'Third thought', 'u': 2500},
      });
      expect(edited.restoring(elsewhere)[_genesis3_22]!.note, 'Third thought');
    });

    test('still lets a removal the backup holds, later than the note here, remove it', () {
      final here = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': 'Written here', 'u': 20},
      });
      final removedLater = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': null, 'u': 30},
      });
      expect(here.restoring(removedLater)[_genesis3_22], isNull);
      expect(here.restoring(removedLater).entries['Genesis 3:22']!.isRemoved, isTrue);
      final removedEarlier = Annotations.fromJson({
        'Genesis 3:22': {'b': false, 'n': null, 'u': 10},
      });
      expect(here.restoring(removedEarlier), here);
    });

    test('adds what it holds that isn\'t here at all, keeps what is only here, and changes nothing twice', () {
      final backup = Annotations.fromJson({
        'Genesis 1:1': {'b': true, 'n': 'Bereshit', 'bu': 5, 'nu': 4, 'u': 5, 'c': 'gold'},
        'Genesis 1:2': 'from a newer version',
      });
      final here = Annotations.fromJson({
        'Exodus 3:14': {'b': true, 'n': null, 'u': 7},
        'Genesis 1:3': 'from a newer version here',
      });
      final restored = here.restoring(backup);
      expect(restored.toJson(), {
        'Genesis 1:1': {'b': true, 'n': 'Bereshit', 'bu': 1000, 'nu': 1000, 'u': 1000, 'c': 'gold'},
        'Genesis 1:2': 'from a newer version',
        'Genesis 1:3': 'from a newer version here',
        'Exodus 3:14': {'b': true, 'n': null, 'bu': 7, 'nu': 7, 'u': 7},
      });
      clock = 2000;
      expect(restored.restoring(backup), restored);
      expect(here.restoring(Annotations.empty), here);
    });

    test('keeps what a newer version stored with a verse marked here, and takes the backup\'s with one restored whole', () {
      final backup = Annotations.fromJson({
        'Genesis 1:1': {'b': true, 'n': 'Bereshit', 'u': 5, 'c': 'gold'},
        'Genesis 3:22': {'b': true, 'n': 'Why?', 'u': 5, 'c': 'gold'},
      });
      final here = Annotations.fromJson({
        'Genesis 1:1': {'b': true, 'n': null, 'u': 8, 'c': 'silver'},
        'Genesis 3:22': {'b': false, 'n': null, 'u': 8},
      });
      final restored = here.restoring(backup);
      expect(restored.entries['Genesis 1:1']!.extra, {'c': 'silver'});
      expect(restored.entries['Genesis 3:22']!.extra, {'c': 'gold'});
    });
  });

  group('the sync payload', () {
    test('carries the annotations, and leaves them out while there are none', () {
      final notes = Annotations.empty.withNote(_genesis3_22, 'For Shabbat');
      final payload = syncPayload(const ProgressState(), null, annotations: notes);
      expect(syncPayloadAnnotations(jsonDecode(jsonEncode(payload)) as Map<String, dynamic>), notes);
      expect(syncPayload(const ProgressState(), null).containsKey('annotations'), isFalse);
      expect(syncPayloadAnnotations(syncPayload(const ProgressState(), null)), Annotations.empty);
      // A tombstone alone still goes, so that the deletion reaches the rest.
      final deleted = notes.withNote(_genesis3_22, null);
      expect(syncPayload(const ProgressState(), null, annotations: deleted)['annotations'], isNotEmpty);
    });

    test('still reads as progress to the version before annotations', () {
      final payload = syncPayload(
        const ProgressState(),
        null,
        annotations: Annotations.empty.withBookmark(_genesis3_22, true),
      );
      expect(ProgressState.fromJson(payload), const ProgressState());
    });
  });

  group('syncing between devices', () {
    test('a note written on one device reaches another, and once deleted there stays deleted', () async {
      final cloud = _Cloud();

      // The phone writes a note, and backs it up.
      var phone = await _device(cloud);
      phone.read(annotationsProvider.notifier).setNote(_genesis3_22, 'Why “like one of us”?');
      expect(await phone.read(progressSyncProvider.notifier).syncNow(), isTrue);
      final phoneStorage = _storage(phone);
      phone.dispose();

      // The tablet signs in, and has it.
      clock = 2000;
      var tablet = await _device(cloud);
      await tablet.read(progressSyncProvider.notifier).syncNow();
      expect(tablet.read(annotationsProvider)[_genesis3_22]?.note, 'Why “like one of us”?');

      // The tablet deletes it, and backs that up.
      clock = 3000;
      tablet.read(annotationsProvider.notifier).setNote(_genesis3_22, null);
      expect(await tablet.read(progressSyncProvider.notifier).syncNow(), isTrue);
      final tabletStorage = _storage(tablet);
      tablet.dispose();
      expect(syncPayloadAnnotations(cloud.backup!).entries['Genesis 3:22']!.isRemoved, isTrue);

      // The phone, which still has the note, syncs: it goes, and the cloud
      // keeps it gone.
      clock = 4000;
      phone = await _device(cloud, stored: phoneStorage);
      expect(phone.read(annotationsProvider)[_genesis3_22], isNull, reason: 'the sync as backup starts');
      await phone.read(progressSyncProvider.notifier).syncNow();
      expect(phone.read(annotationsProvider)[_genesis3_22], isNull);
      expect(syncPayloadAnnotations(cloud.backup!)[_genesis3_22], isNull);
      expect(
        Annotations.fromJson(jsonDecode(phone.read(sharedPreferencesProvider).getString(AnnotationsController.storageKey)!)),
        syncPayloadAnnotations(cloud.backup!),
        reason: 'the deletion is stored on the phone too',
      );
      phone.dispose();

      // And the tablet, syncing again, doesn't bring it back.
      tablet = await _device(cloud, stored: tabletStorage);
      await tablet.read(progressSyncProvider.notifier).syncNow();
      expect(tablet.read(annotationsProvider)[_genesis3_22], isNull);
      tablet.dispose();
    });

    test('a bookmark made on each device keeps both, and a backup made by an older version loses neither', () async {
      final cloud = _Cloud();
      var phone = await _device(cloud);
      phone.read(annotationsProvider.notifier).setBookmark(_genesis1_1, true);
      await phone.read(progressSyncProvider.notifier).syncNow();
      final phoneStorage = _storage(phone);
      phone.dispose();

      var tablet = await _device(cloud);
      await tablet.read(progressSyncProvider.notifier).syncNow();
      tablet.read(annotationsProvider.notifier).setBookmark(_exodus3_14, true);
      await tablet.read(progressSyncProvider.notifier).syncNow();
      expect(syncPayloadAnnotations(cloud.backup!).inTorah, hasLength(2));
      final tabletStorage = _storage(tablet);
      tablet.dispose();

      // An older version saves the progress without them.
      cloud.backup = {...cloud.backup!}..remove('annotations');

      phone = await _device(cloud, stored: phoneStorage);
      await phone.read(progressSyncProvider.notifier).syncNow();
      expect(phone.read(annotationsProvider)[_genesis1_1]?.bookmarked, isTrue);
      expect(syncPayloadAnnotations(cloud.backup!)[_genesis1_1]?.bookmarked, isTrue, reason: 'backed up again');
      phone.dispose();
      tablet = await _device(cloud, stored: tabletStorage);
      await tablet.read(progressSyncProvider.notifier).syncNow();
      expect([for (final (v, _) in syncPayloadAnnotations(cloud.backup!).inTorah) v], [_genesis1_1, _exodus3_14]);
      tablet.dispose();
    });
  });

  group('a backup file imported', () {
    test('brings back a note deleted since, on every device', () async {
      final cloud = _Cloud();

      // The phone writes a note, saves a backup file, then deletes the note,
      // and the deletion reaches the tablet.
      var phone = await _device(cloud);
      phone.read(annotationsProvider.notifier).setNote(_genesis3_22, 'For Shabbat');
      final file = encodeBackup(
        const ProgressState(),
        const AppSettings(),
        annotations: phone.read(annotationsProvider),
        now: DateTime.utc(2026, 10, 11),
      );
      clock = 2000;
      phone.read(annotationsProvider.notifier).setNote(_genesis3_22, null);
      expect(await phone.read(progressSyncProvider.notifier).syncNow(), isTrue);
      final phoneStorage = _storage(phone);
      phone.dispose();
      var tablet = await _device(cloud);
      await tablet.read(progressSyncProvider.notifier).syncNow();
      expect(tablet.read(annotationsProvider)[_genesis3_22], isNull);
      final tabletStorage = _storage(tablet);
      tablet.dispose();

      // The phone imports the file: the note is back, and stays back.
      clock = 3000;
      phone = await _device(cloud, stored: phoneStorage);
      phone.read(annotationsProvider.notifier).restore(parseBackup(file)!.annotations);
      expect(phone.read(annotationsProvider)[_genesis3_22]?.note, 'For Shabbat');
      expect(await phone.read(progressSyncProvider.notifier).syncNow(), isTrue);
      expect(phone.read(annotationsProvider)[_genesis3_22]?.note, 'For Shabbat');
      expect(syncPayloadAnnotations(cloud.backup!)[_genesis3_22]?.note, 'For Shabbat');
      phone.dispose();

      // And reaches the tablet, which had the deletion.
      tablet = await _device(cloud, stored: tabletStorage);
      await tablet.read(progressSyncProvider.notifier).syncNow();
      expect(tablet.read(annotationsProvider)[_genesis3_22]?.note, 'For Shabbat');
      tablet.dispose();
    });
  });

  group('storage', () {
    test('is read back as it was saved', () async {
      final cloud = _Cloud();
      final c = await _device(cloud);
      c.read(annotationsProvider.notifier)
        ..setBookmark(_genesis3_22, true)
        ..setNote(_genesis1_1, 'In the beginning');
      final stored = _storage(c);
      final saved = c.read(annotationsProvider);
      c.dispose();
      final again = await _device(cloud, stored: stored);
      expect(again.read(annotationsProvider), saved);
      again.dispose();
    });

    test('that can\'t be read is copied aside, once, and the reader starts with none', () async {
      final cloud = _Cloud();
      for (var i = 0; i < 2; i++) {
        final c = await _device(cloud, stored: {
          AnnotationsController.storageKey: '{not json',
          if (i == 1) '${AnnotationsController.corruptBackupPrefix}1': '{not json',
        });
        expect(c.read(annotationsProvider), Annotations.empty);
        final prefs = c.read(sharedPreferencesProvider);
        final copies = prefs.getKeys().where((k) => k.startsWith(AnnotationsController.corruptBackupPrefix));
        expect(copies, hasLength(1));
        c.dispose();
      }
    });
  });

  group('a backup file', () {
    test('holds the annotations, and gives them back', () {
      final notes = Annotations.empty.withBookmark(_genesis3_22, true).withNote(_genesis1_1, 'Bereshit');
      final file = encodeBackup(const ProgressState(), const AppSettings(), annotations: notes, now: DateTime.utc(2026, 10, 11));
      expect(parseBackup(file)!.annotations, notes);
      // One made before they were kept has none.
      final old = jsonEncode({'app': 'shnayim_mikra', 'progress': const ProgressState().toJson()});
      expect(parseBackup(old)!.annotations, Annotations.empty);
    });
  });
}
