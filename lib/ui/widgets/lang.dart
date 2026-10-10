import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Tags its subtree with the language it is written in, so that a screen
/// reader reads it in that language's voice: English inside the Hebrew
/// interface, or Hebrew inside the English one. On the web it becomes the
/// `lang` attribute of the subtree's elements.
class Lang extends StatelessWidget {
  const Lang(this.locale, {super.key, required this.child});

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(localeForSubtree: locale, child: child);
}

/// Whether a screen reader here takes a node's language only from the node
/// as a whole, so that a label in two languages is better given in one. So
/// it is on the web, whose engine ignores label attributes and sets `lang`
/// from the node's locale. TalkBack and VoiceOver switch voice partway
/// through a label, where a [LocaleStringAttribute] marks a span in another
/// language. Flutter's Windows bridge passes no language at all, so there a
/// label is best in the interface language, which the screen reader's voice
/// reads.
bool get nodeLanguageOnly => debugNodeLanguageOnly ?? kIsWeb;

/// Overrides [nodeLanguageOnly], for tests of the web's labels.
@visibleForTesting
bool? debugNodeLanguageOnly;
