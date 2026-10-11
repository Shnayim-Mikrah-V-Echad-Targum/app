import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/verse_ref.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../community/ui/community_ui.dart' show autoDirection, quietCounter;
import 'domain/annotations.dart';

/// The language a screen reader should read [note] in, where it is written
/// in the other direction from [context]'s interface: Hebrew for a note
/// written right to left in the English UI, English for one written left to
/// right in the Hebrew UI. Null where the interface's own voice reads it.
Locale? noteLocale(BuildContext context, String note) {
  final ui = Directionality.of(context);
  final written = autoDirection(note, fallback: ui);
  if (written == ui) return null;
  return written == TextDirection.rtl ? const Locale('he') : const Locale('en');
}

/// Opens the reader's note on [verse] for writing, over [context]'s page,
/// and saves what they write: the page then says it was saved, or, for a
/// note deleted, offers to undo that.
Future<void> editVerseNote(BuildContext context, BookVerse verse) async {
  final l = context.l10n;
  final container = ProviderScope.containerOf(context, listen: false);
  final reference = Names(context).reference(verse.book, verse.ref.chapter, verse.ref.verse);
  final before = container.read(annotationsProvider)[verse]?.note;
  final text = await showAppDialog<String>(
    context: context,
    builder: (_) => NoteDialog(reference: reference, note: before),
  );
  if (text == null) return;
  // The status message outlives the page, and its container is the app's.
  final notes = container.read(annotationsProvider.notifier)..setNote(verse, text);
  if (!context.mounted) return;
  if (text.trim().isNotEmpty) {
    showStatus(context, l.noteSaved);
  } else if (before != null) {
    showStatus(
      context,
      l.noteDeleted,
      action: SnackBarAction(label: l.actionUndo, onPressed: () => notes.setNote(verse, before)),
    );
  }
}

/// Writes the reader's note on a verse (DESIGN_SYSTEM.md §6.27): a field of
/// up to [kNoteMaxLength] characters, in the direction of what is written,
/// that takes the focus. Save waits for a change; Delete, for a note there
/// is. It returns the text to save, empty to delete the note, or null.
class NoteDialog extends StatefulWidget {
  const NoteDialog({super.key, required this.reference, this.note});

  /// The verse, as the title names it.
  final String reference;

  /// The note as it stands, if any.
  final String? note;

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final _text = TextEditingController(text: widget.note);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Whether the field holds a change to save: a new note, a changed one, or
  /// a note emptied, which deletes it.
  bool _changed(String text) => text.trim() != (widget.note ?? '').trim();

  void _save() {
    if (_changed(_text.text)) Navigator.pop(context, _text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final apple = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    return ValueListenableBuilder(
      valueListenable: _text,
      builder: (context, value, _) => CallbackShortcuts(
        // Ctrl+Enter (⌘Enter) saves, as it posts in a new discussion.
        bindings: {
          for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter])
            SingleActivator(key, control: !apple, meta: apple): _save,
        },
        child: AlertDialog(
          scrollable: true,
          title: Text(l.noteTitle(widget.reference)),
          // As wide as the dialog can be, for a paragraph or two.
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: _text,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              maxLength: kNoteMaxLength,
              buildCounter: quietCounter,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textDirection: autoDirection(value.text, fallback: Directionality.of(context)),
              decoration: InputDecoration(
                labelText: l.yourNote,
                hintText: l.noteHint,
                hintMaxLines: 2,
                // At the top of the tall field, not in its middle.
                alignLabelWithHint: true,
              ),
            ),
          ),
          // Stacked on a narrow screen, Save comes first.
          actionsOverflowDirection: VerticalDirection.up,
          actions: [
            if (widget.note != null) TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(l.actionDelete)),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
            FilledButton(onPressed: _changed(value.text) ? _save : null, child: Text(l.actionSave)),
          ],
        ),
      ),
    );
  }
}
