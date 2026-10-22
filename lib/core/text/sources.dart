import '../../data/models/verse_ref.dart';

/// Where a reader checks the app's texts against their sources: the checksums
/// of every source file and every file the app ships, which
/// `tool/data/build_data.mjs` writes to `assets/text/SOURCES.json`.
final Uri sourcesManifestUri = Uri.parse(
  'https://github.com/Shnayim-Mikrah-V-Echad-Targum/app/blob/main/assets/text/SOURCES.json',
);

/// The verse's own page on Sefaria, with its Hebrew and English side by side:
/// the same public editions the app is built from, so that the verse can be
/// compared with the app's. Sefaria names a verse by its book, chapter and
/// verse, with a space in a book's name written as an underscore.
Uri sefariaVerseUri(BookVerse at) => Uri.https(
      'www.sefaria.org',
      '/${at.book.trim().replaceAll(' ', '_')}.${at.ref.chapter}.${at.ref.verse}',
      {'lang': 'bi'},
    );
