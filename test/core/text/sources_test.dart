import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/text/sources.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';

void main() {
  test('a verse opens on Sefaria with its Hebrew and English side by side', () {
    expect(
      sefariaVerseUri(const BookVerse('Genesis', VerseRef(1, 1))).toString(),
      'https://www.sefaria.org/Genesis.1.1?lang=bi',
    );
  });

  test('a book of two words is named with an underscore, as Sefaria names it', () {
    expect(
      sefariaVerseUri(const BookVerse('I Samuel', VerseRef(3, 4))).toString(),
      'https://www.sefaria.org/I_Samuel.3.4?lang=bi',
    );
  });

  test('the manifest is on the repository, on the main branch', () {
    expect(sourcesManifestUri.host, 'github.com');
    expect(sourcesManifestUri.path, endsWith('/assets/text/SOURCES.json'));
  });
}
