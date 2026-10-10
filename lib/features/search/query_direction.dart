import 'package:flutter/widgets.dart';

import '../../core/text/hebrew_text.dart';

/// The direction to set a search or reference being typed in: right to left
/// with any Hebrew in it and left to right with Latin letters alone, whatever
/// the language of the app; while it has neither, null, the page's own.
TextDirection? queryDirection(String text) {
  if (HebrewText.containsHebrew(text)) return TextDirection.rtl;
  if (_latin.hasMatch(text)) return TextDirection.ltr;
  return null;
}

final _latin = RegExp(r'\p{Script=Latin}', unicode: true);
