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

/// Whether screen readers here switch voice partway through a label, where a
/// [LocaleStringAttribute] marks a span in another language. TalkBack and
/// VoiceOver do. Elsewhere only a whole node can be tagged: the web engine
/// ignores label attributes and sets `lang` from the node's locale, and
/// Flutter's Windows bridge passes no language at all.
bool get labelSpansSwitchVoice =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
