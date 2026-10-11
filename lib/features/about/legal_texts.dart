import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The policies the app shows.
enum LegalDoc {
  privacy,
  terms,
  guidelines,
  accessibility;

  /// The policy at [slug], or null for none: a mistyped link leads to no
  /// policy rather than to the wrong one.
  static LegalDoc? fromSlug(String slug) => values.where((d) => d.name == slug).firstOrNull;
}

/// Where a section or block of a policy applies: only where the build has a
/// support address to email, or only where it has none.
enum LegalCondition {
  email,
  noEmail;

  static LegalCondition? _parse(Object? when) => switch (when) {
        null => null,
        'email' => email,
        'no-email' => noEmail,
        _ => throw FormatException('Unknown "when": $when'),
      };

  bool holds({required bool hasEmail}) => this == email ? hasEmail : !hasEmail;
}

/// One block of a policy's section: a paragraph, a bullet or a line with the
/// way to reach us.
sealed class LegalBlock {
  const LegalBlock(this.text, {this.when});

  factory LegalBlock.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String;
    final when = LegalCondition._parse(json['when']);
    return switch (json['type']) {
      'para' => Para(text, when: when),
      'bullet' => Bullet(text, when: when),
      'contact' => ContactLine(text, when: when, subject: json['subject'] as String?),
      final type => throw FormatException('Unknown block type: $type'),
    };
  }

  final String text;
  final LegalCondition? when;
}

final class Para extends LegalBlock {
  const Para(super.text, {super.when});
}

/// An item of a list, whose wrapped lines hang from its bullet.
final class Bullet extends LegalBlock {
  const Bullet(super.text, {super.when});
}

/// A sentence with `{contact}` in it: the support address, or the issue
/// tracker where the build has none.
final class ContactLine extends LegalBlock {
  const ContactLine(super.text, {super.when, this.subject});

  static const placeholder = '{contact}';

  /// The subject of an email sent from it, if not the app's name.
  final String? subject;

  /// The text before the contact and after it.
  (String, String) get parts {
    final at = text.indexOf(placeholder);
    if (at < 0) return (text, '');
    return (text.substring(0, at), text.substring(at + placeholder.length));
  }
}

/// A section of a policy: a heading (empty for the opening paragraphs) and
/// its blocks.
class LegalSection {
  const LegalSection(this.heading, this.blocks, {this.when});

  factory LegalSection.fromJson(Map<String, dynamic> json) => LegalSection(
      json['heading'] as String,
      [
        for (final b in json['blocks'] as List) LegalBlock.fromJson(b as Map<String, dynamic>),
      ],
      when: LegalCondition._parse(json['when']));

  final String heading;
  final List<LegalBlock> blocks;
  final LegalCondition? when;
}

/// The policies in both languages, from assets/legal/legal.json, which the
/// static web pages are also made from (tool/legal/build_html.mjs). The file
/// holds the web's own pages too; the app reads only its [LegalDoc]s.
class LegalTexts {
  LegalTexts._(this._docs, this._updated);

  /// Parses legal.json, shaped as `{updated: {doc: 'yyyy-mm'}, en: {doc:
  /// [{heading, when?, blocks: [{type, text, when?, subject?}]}]}, he: …}`.
  factory LegalTexts.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final docs = <(String, LegalDoc), List<LegalSection>>{};
    for (final lang in const ['en', 'he']) {
      final texts = json[lang] as Map<String, dynamic>;
      for (final doc in LegalDoc.values) {
        final sections = texts[doc.name] as List?;
        if (sections == null) throw FormatException('No $lang text for ${doc.name}');
        docs[(lang, doc)] = [for (final s in sections) LegalSection.fromJson(s as Map<String, dynamic>)];
      }
    }
    final updated = <LegalDoc, DateTime>{};
    final months = (json['updated'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    for (final MapEntry(:key, :value) in months.entries) {
      final doc = LegalDoc.fromSlug(key);
      final month = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value as String);
      if (month == null) throw FormatException('"updated" is not yyyy-mm: $value');
      if (doc != null) updated[doc] = DateTime(int.parse(month[1]!), int.parse(month[2]!));
    }
    return LegalTexts._(docs, updated);
  }

  static const asset = 'assets/legal/legal.json';

  final Map<(String, LegalDoc), List<LegalSection>> _docs;
  final Map<LegalDoc, DateTime> _updated;

  /// [doc] in Hebrew or English, with only the sections and blocks that
  /// apply where the build has a support address ([hasEmail]) or not.
  List<LegalSection> sections(LegalDoc doc, {required bool hebrew, required bool hasEmail}) => [
        for (final s in _docs[(hebrew ? 'he' : 'en', doc)]!)
          if (s.when?.holds(hasEmail: hasEmail) ?? true)
            LegalSection(s.heading, [
              for (final b in s.blocks)
                if (b.when?.holds(hasEmail: hasEmail) ?? true) b,
            ]),
      ];

  /// The month [doc] was last changed, if the file says.
  DateTime? updated(LegalDoc doc) => _updated[doc];
}

/// The policies, read once from the bundle. Decoded here rather than with
/// `loadString`, which hands a file of 50 KB or more to another isolate, for
/// a file this small a round trip slower than decoding it.
final legalTextsProvider = FutureProvider<LegalTexts>((ref) async {
  final data = await rootBundle.load(LegalTexts.asset);
  return LegalTexts.parse(utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
});
