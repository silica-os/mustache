// The preview pane (⇧⌘P, MU-05, docs/spec/preview-pane.md for the behaviour; kit `Apps/Mustache/Preview
// Pane`): right of the content, 260 wide on the sidebar surface with a 1 pt separator on its left
// edge. The same pane serves the gallery and the column view.
//
// From the top: the preview 128 × 128 (24 from the top, centered), the name in Body Emphasis and
// "Kind - size" in Callout, both centered, 20 apart; Information (Body Emphasis) with 28 pt rows
// (label and value in Callout, a 1 pt separator above each row and one below the last), the "add
// a tag" field (a 28 pt search field, 20 below the last separator); at the bottom a 1 pt
// separator and the action buttons (secondary, 28 tall, 20 from the left, 20 above the bottom).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'icon_view.dart' show EntryIcon, hasThumbnail;
import 'info.dart' show StatDetails;
import 'model.dart';
import 'quick_preview.dart' show isTextPreview;

const double previewPaneWidth = 260;
const double previewSide = 128;
const double previewTop = 24;
const double paneRow = 28;
const double paneActionsHeight = 72;
const double panePadding = 16;

/// An action of the bottom bar: a button; it receives the point of the button (to open a menu
/// there).
class PaneAction {
  const PaneAction(this.label, this.symbol, this.onPressed);
  final String label;

  /// The Icon Kit symbol (kept for callers; the kit's buttons carry a label only).
  final String symbol;
  final ValueChanged<Offset> onPressed;
}

class PreviewPane extends StatelessWidget {
  const PreviewPane({
    super.key,
    required this.items,
    required this.kindOf,
    this.env,
    this.width = previewPaneWidth,
    this.now,
    this.tagsOf,
    this.onAddTag,
    this.onTagsChanged,
    this.actions = const [],
  });

  final double width;

  /// The selection (empty: nothing).
  final List<Entry> items;
  final String Function(Entry entry) kindOf;
  final Map<String, String>? env;

  /// For "today" and "yesterday" in dates (tests fix the time).
  final DateTime? now;

  /// The tags of an item and adding one from the field.
  final List<String> Function(Entry entry)? tagsOf;
  final void Function(Entry entry, String tag)? onAddTag;
  final void Function(Entry entry, List<String> tags)? onTagsChanged;

  /// The buttons of the bottom bar (empty: no bar).
  final List<PaneAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final content = items.isEmpty
        ? const SizedBox.expand()
        : items.length > 1
        ? _many(colors)
        : _one(colors, items.single);
    return SizedBox(
      key: const ValueKey('preview pane'),
      width: width,
      child: ColoredBox(
        color: colors.surfaceSidebar,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: content),
                if (items.isNotEmpty && actions.isNotEmpty) _actionsBar(colors),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 1,
              child: ColoredBox(color: colors.lineSeparator),
            ),
          ],
        ),
      ),
    );
  }

  Widget _many(AmalfiColors colors) {
    final total = items.fold<int>(
      0,
      (sum, e) => sum + (e.isDirectory ? 0 : e.size),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: previewTop),
        SizedBox(
          height: previewSide,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A fan of rotated icons.
              for (var i = 0; i < items.length && i < 3; i++)
                Transform.rotate(
                  angle: (i - 1) * 0.12,
                  child: EntryIcon(
                    entry: items[i],
                    side: previewSide * 0.75,
                    env: env,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: panePadding),
          child: Text(
            l10n.itemCount(items.length),
            textAlign: TextAlign.center,
            style: AmalfiType.bodyEmphasis(color: colors.textPrimary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: panePadding),
          child: Text(
            l10n.documentsSize(
              items.length,
              formatSize(
                Entry(
                  name: '',
                  path: '',
                  isDirectory: false,
                  size: total,
                  modified: DateTime(0),
                ),
              ),
            ),
            textAlign: TextAlign.center,
            style: AmalfiType.callout(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }

  /// `stat` per path and date: not on every paint.
  static final Map<String, StatDetails> _stats = {};

  String _when(DateTime? t) =>
      t == null ? '--' : formatDate(t, now ?? DateTime.now());

  Widget _one(AmalfiColors colors, Entry entry) {
    final key = '${entry.path}\u0000${entry.modified.microsecondsSinceEpoch}';
    if (_stats.length > 500) _stats.clear();
    final stat = _stats[key] ??= StatDetails.of(entry.path);
    final kind = entry.isDirectory
        ? kindOf(entry)
        : '${kindOf(entry)} - ${formatSize(entry)}';
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: panePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: previewTop),
            SizedBox(height: previewSide, child: _preview(entry)),
            const SizedBox(height: 16),
            Text(
              entry.name,
              key: const ValueKey('pane name'),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.bodyEmphasis(color: colors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              kind,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.callout(color: colors.textSecondary),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.information,
              style: AmalfiType.bodyEmphasis(color: colors.textPrimary),
            ),
            const SizedBox(height: 14),
            _separator(colors),
            _row(colors, l10n.created, _when(stat.created)),
            _separator(colors),
            _row(colors, l10n.modified, _when(entry.modified)),
            if (hasThumbnail(entry.name)) ...[
              _separator(colors),
              _row(colors, l10n.size, formatSize(entry)),
            ],
            _separator(colors),
            if (tagsOf != null) ...[
              const SizedBox(height: 20),
              _TagField(
                key: ValueKey('tags field ${entry.path}'),
                tags: tagsOf!(entry),
                onAdd: (tag) => onAddTag?.call(entry, tag),
                onTagsChanged: (tags) => onTagsChanged?.call(entry, tags),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _separator(AmalfiColors colors) =>
      SizedBox(height: 1, child: ColoredBox(color: colors.lineSeparator));

  /// A 27 pt row (28 with its separator): label on the left, value on the right, in Callout.
  Widget _row(AmalfiColors colors, String label, String value) => SizedBox(
    height: paneRow - 1,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            label,
            style: AmalfiType.callout(color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.callout(color: colors.textPrimary),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _actionsBar(AmalfiColors colors) => SizedBox(
    key: const ValueKey('pane actions'),
    height: paneActionsHeight,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _separator(colors),
        Expanded(
          child: Padding(
            // The buttons start 20 below the separator (kit: y 536 under the line at 516).
            padding: const EdgeInsets.fromLTRB(20, 19, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                for (final action in actions)
                  Builder(
                    builder: (context) => KeyedSubtree(
                      key: ValueKey('action ${action.label}'),
                      child: AmalfiPushButton(
                        label: action.label,
                        onPressed: () {
                          final box = context.findRenderObject()! as RenderBox;
                          action.onPressed(box.localToGlobal(Offset.zero));
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _preview(Entry entry) {
    if (hasThumbnail(entry.name)) {
      return Image.file(
        File(entry.path),
        fit: BoxFit.contain,
        cacheWidth: 488,
        errorBuilder: (_, _, _) => Center(
          child: EntryIcon(entry: entry, side: previewSide, env: env),
        ),
      );
    }
    if (!entry.isDirectory && isTextPreview(entry.name)) {
      var text = '';
      try {
        final f = File(entry.path).openSync();
        try {
          text = String.fromCharCodes(f.readSync(8192));
        } finally {
          f.closeSync();
        }
      } on FileSystemException {
        text = '';
      }
      return Builder(
        builder: (context) {
          final colors = AmalfiTheme.of(context).colors;
          return DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.surfaceRaised,
              shape: AmalfiSmoothBorder(
                radius: 8,
                side: BorderSide(
                  color: colors.lineSeparator,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRect(
                child: Text(
                  text,
                  overflow: TextOverflow.fade,
                  style: AmalfiType.mono(
                    color: colors.textPrimary,
                  ).copyWith(fontSize: 8, height: 1.2),
                ),
              ),
            ),
          );
        },
      );
    }
    return Center(
      child: EntryIcon(entry: entry, side: previewSide, env: env),
    );
  }
}

/// The tags field (kit `Fields/Search Field/Regular`): shows the item's tags as tokens, Return adds
/// one.
class _TagField extends StatefulWidget {
  const _TagField({
    super.key,
    required this.tags,
    required this.onAdd,
    this.onTagsChanged,
  });
  final List<String> tags;
  final ValueChanged<String> onAdd;
  final ValueChanged<List<String>>? onTagsChanged;

  @override
  State<_TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<_TagField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final tag = value.trim();
    if (tag.isEmpty) return;
    widget.onAdd(tag);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) => AmalfiSearchField(
    controller: _controller,
    placeholder: l10n.addTag,
    tokens: widget.tags,
    onTokensChanged: widget.onTagsChanged,
    width: previewPaneWidth - 2 * panePadding,
    onSubmitted: _submit,
  );
}
