// The Get Info window (⌘I, MU-60, docs/spec/info.md for the behaviour; kit `Apps/Mustache/Info`):
// 264 wide, as tall as its content, content padding 16; a header with the 48 pt icon, the name in
// Body Emphasis, the size (an item count for a folder) and the date, then the tags field; sections
// separated by 1 pt lines with a 12 pt disclosure chevron that open and close (the state applies to
// all Info windows, R11.1): General, Name & Extension, Comments, Open With, Preview, Sharing &
// Permissions. Labels in a 64 pt column, values from x 92, Callout text. A folder's colour, symbol
// and emoji are not here: they have their own popover (folder_customize.dart). The kit's "More
// Info" section is not here: there is nothing to put in it yet (mustache issue).
//
// In Silica every Get Info is its own window, a child of the Mustache window (mustache#12,
// silica-desktop#146): Ossido draws its title bar and close button, and the panel is its content
// (`framed: false`). Where the system cannot open windows (the desktop layer, an older Silica)
// it is drawn inside the Mustache window with its own frame, as before.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'icon_view.dart' show EntryIcon;
import 'model.dart';
import 'xattr.dart';

const double infoWidth = 264;
const double infoPadding = 16;
const double infoLabelWidth = 64;
const double infoSectionHeight = 28;
const double infoRow = 20;

/// Images larger than this are not read for their dimensions.
const int _maxImageBytes = 64 << 20;

/// The sections, in order.
enum InfoSection {
  general,
  more,
  name,
  comments,
  openWith,
  preview,
  permissions,
}

String infoSectionTitle(InfoSection s) => switch (s) {
  InfoSection.general => l10n.infoGeneral,
  InfoSection.more => l10n.infoMoreInfo,
  InfoSection.name => l10n.infoNameExtension,
  InfoSection.comments => l10n.infoComments,
  InfoSection.openWith => l10n.openWith,
  InfoSection.preview => l10n.infoPreview,
  InfoSection.permissions => l10n.infoPermissions,
};

/// What `stat` says about a file that `FileStat` does not have: creation, disk usage, owner and
/// group.
class StatDetails {
  const StatDetails({
    this.created,
    this.accessed,
    this.blocks = 0,
    this.owner = '',
    this.group = '',
    this.mode = 0,
  });

  final DateTime? created;
  final DateTime? accessed;
  final int blocks;
  final String owner;
  final String group;
  final int mode;

  int get onDisk => blocks * 512;

  /// From the output of `stat -c '%W %b %U %G %a %X'` (the last field is optional).
  static StatDetails parse(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 5) return const StatDetails();
    final birth = int.tryParse(parts[0]) ?? 0;
    return StatDetails(
      created: birth > 0
          ? DateTime.fromMillisecondsSinceEpoch(birth * 1000)
          : null,
      accessed: parts.length > 5 && (int.tryParse(parts[5]) ?? 0) > 0
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(parts[5]) * 1000)
          : null,
      blocks: int.tryParse(parts[1]) ?? 0,
      owner: parts[2],
      group: parts[3],
      mode: int.tryParse(parts[4], radix: 8) ?? 0,
    );
  }

  static StatDetails of(String path) {
    try {
      final r = Process.runSync('stat', ['-c', '%W %b %U %G %a %X', path]);
      return r.exitCode == 0 ? parse('${r.stdout}') : const StatDetails();
    } on ProcessException {
      return const StatDetails();
    }
  }
}

/// The privileges of a class (owner, group, others) as the menu shows them.
enum Privilege { readWrite, readOnly, writeOnly, none }

String privilegeLabel(Privilege p) => switch (p) {
  Privilege.readWrite => l10n.privilegeReadWrite,
  Privilege.readOnly => l10n.privilegeReadOnly,
  Privilege.writeOnly => l10n.privilegeWriteOnly,
  Privilege.none => l10n.privilegeNone,
};

/// The privileges of the class `shift` (6 owner, 3 group, 0 others) in the mode.
Privilege privilegeOf(int mode, int shift) {
  final r = mode >> (shift + 2) & 1 == 1;
  final w = mode >> (shift + 1) & 1 == 1;
  return r && w
      ? Privilege.readWrite
      : r
      ? Privilege.readOnly
      : w
      ? Privilege.writeOnly
      : Privilege.none;
}

/// The mode with the privileges of the class `shift` changed (execute stays as it is).
int withPrivilege(int mode, int shift, Privilege p) {
  final bits = switch (p) {
    Privilege.readWrite => 6,
    Privilege.readOnly => 4,
    Privilege.writeOnly => 2,
    Privilege.none => 0,
  };
  return (mode & ~(6 << shift)) | (bits << shift);
}

String _date(DateTime? t) => t == null ? '--' : longDate(t);

class InfoPanel extends StatefulWidget {
  const InfoPanel({
    super.key,
    required this.entry,
    required this.kind,
    required this.open,
    required this.onToggle,
    required this.onClose,
    required this.onRename,
    this.openWith,
    this.mime,
    this.env,
    this.framed = true,
    this.onHeight,
    this.tags,
    this.onAddTag,
    this.onTagsChanged,
  });

  final Entry entry;

  /// Drawn inside the Mustache window, with its own frame, shadow and title bar; false when it
  /// is the content of a real window (Ossido draws the bar and the close button).
  final bool framed;

  /// The height of the content, after every layout that changes it (the window follows it:
  /// as tall as its content, as on the reference).
  final ValueChanged<double>? onHeight;

  /// The description of the type (as in the Kind column).
  final String kind;

  /// The open sections and the click on the chevron.
  final Set<InfoSection> open;
  final ValueChanged<InfoSection> onToggle;
  final VoidCallback onClose;

  /// The name typed in the Name field (Return renames right away, R8.8).
  final ValueChanged<String> onRename;

  /// The app that opens the file (null for folders).
  final String? openWith;

  /// The MIME type of a file (More Info); null for folders.
  final String? mime;
  final Map<String, String>? env;

  /// The item's tags and adding one from the field (null: no field).
  final List<String>? tags;
  final ValueChanged<String>? onAddTag;
  final ValueChanged<List<String>>? onTagsChanged;

  @override
  State<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends State<InfoPanel> {
  late StatDetails _stat = StatDetails.of(widget.entry.path);
  late final TextEditingController _name = TextEditingController(
    text: widget.entry.name,
  );
  late final TextEditingController _comment = TextEditingController(
    text: readAttribute(widget.entry.path, commentAttribute) ?? '',
  );
  final TextEditingController _tagInput = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final GlobalKey _contentKey = GlobalKey();
  double? _reportedHeight;

  /// The pixel size of an image, once read (More Info); null while loading or when it is not one.
  ({int width, int height})? _dimensions;

  @override
  void initState() {
    super.initState();
    _readDimensions();
    // The comment is saved when leaving the field (R11.2).
    _commentFocus.addListener(() {
      if (!_commentFocus.hasFocus) {
        writeAttribute(
          widget.entry.path,
          commentAttribute,
          _comment.text.trim(),
        );
      }
    });
  }

  @override
  void didUpdateWidget(InfoPanel old) {
    super.didUpdateWidget(old);
    if (old.entry.path != widget.entry.path) {
      _stat = StatDetails.of(widget.entry.path);
      _name.text = widget.entry.name;
      _comment.text = readAttribute(widget.entry.path, commentAttribute) ?? '';
      _dimensions = null;
      _readDimensions();
    }
  }

  /// Reads the size of an image file from its header, off the first frame.
  Future<void> _readDimensions() async {
    final path = widget.entry.path;
    final mime = widget.mime;
    if (widget.entry.isDirectory ||
        mime == null ||
        !mime.startsWith('image/') ||
        widget.entry.size > _maxImageBytes) {
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final size = (width: descriptor.width, height: descriptor.height);
        descriptor.dispose();
        if (mounted && widget.entry.path == path) {
          setState(() => _dimensions = size);
        }
      } finally {
        buffer.dispose();
      }
    } on Object {
      // Not an image the engine decodes: the row stays at "--".
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    _tagInput.dispose();
    _commentFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  AmalfiColors get _c => AmalfiTheme.of(context).colors;

  /// Tells [InfoPanel.onHeight] the content's height once it is laid out, if it changed.
  void _reportHeight() {
    final report = widget.onHeight;
    if (report == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _contentKey.currentContext?.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) return;
      final height = box.size.height;
      if (height == _reportedHeight) return;
      _reportedHeight = height;
      report(height);
    });
  }

  Widget _body(Entry entry) => Column(
    key: _contentKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      _header(entry),
      for (final section in InfoSection.values)
        if (switch (section) {
          InfoSection.openWith => !entry.isDirectory,
          _ => true,
        })
          _section(section),
      const SizedBox(height: infoPadding),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    _reportHeight();
    if (!widget.framed) {
      // The window's content: the window draws the bar, the frame and the shadow.
      return ColoredBox(
        key: ValueKey('info ${entry.path}'),
        color: _c.surfaceWindow,
        child: SingleChildScrollView(child: _body(entry)),
      );
    }
    return SizedBox(
      key: ValueKey('info ${entry.path}'),
      width: infoWidth,
      child: AmalfiWindow(
        kind: AmalfiWindowKind.utility,
        active: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [_titleBar(entry), _body(entry)],
          ),
        ),
      ),
    );
  }

  /// The title-only bar (kit `Titlebars/Bar/Title Only`): 32 tall, the close control on the left
  /// and the title.
  Widget _titleBar(Entry entry) => SizedBox(
    height: AmalfiToolbarMetrics.titleOnlyHeight,
    child: Stack(
      children: [
        Positioned(
          left: 12,
          top: 8,
          child: GestureDetector(
            key: const ValueKey('close info'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: const AmalfiWindowDot(kind: AmalfiWindowControlKind.close),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              l10n.infoTitle(entry.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.headline(color: _c.textPrimary),
            ),
          ),
        ),
      ],
    ),
  );

  /// The item count of a folder, for the line under the name (the size for a file).
  String _sizeLine(Entry entry) {
    if (!entry.isDirectory) return formatSize(entry);
    try {
      return l10n.itemCount(Directory(entry.path).listSync().length);
    } on FileSystemException {
      return '--';
    }
  }

  Widget _header(Entry entry) => Padding(
    padding: const EdgeInsets.fromLTRB(infoPadding, 16, infoPadding, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: EntryIcon(entry: entry, side: 48, env: widget.env),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AmalfiType.bodyEmphasis(color: _c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sizeLine(entry),
                      style: AmalfiType.callout(color: _c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.modifiedOn(_date(entry.modified)),
          style: AmalfiType.callout(color: _c.textSecondary),
        ),
        if (widget.tags != null) ...[
          const SizedBox(height: 12),
          AmalfiSearchField(
            key: ValueKey('info tags ${entry.path}'),
            controller: _tagInput,
            placeholder: l10n.addTag,
            tokens: widget.tags!,
            onTokensChanged: widget.onTagsChanged,
            width: infoWidth - 2 * infoPadding,
            onSubmitted: (value) {
              final tag = value.trim();
              if (tag.isEmpty) return;
              widget.onAddTag?.call(tag);
              _tagInput.clear();
            },
          ),
        ],
      ],
    ),
  );

  Widget _section(InfoSection section) {
    final open = widget.open.contains(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: _c.lineSeparator),
        GestureDetector(
          key: ValueKey('section ${section.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onToggle(section),
          child: SizedBox(
            height: infoSectionHeight - 1,
            // The title 4 below the separator and the chevron 8 (kit `Info`: y 184 and 188 under
            // the line at 180).
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: infoPadding),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AmalfiGlyph(
                      open
                          ? AmalfiGlyphs.chevronDown
                          : AmalfiGlyphs.chevronRight,
                      size: 12,
                      color: _c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      infoSectionTitle(section),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AmalfiType.bodyEmphasis(color: _c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _content(section),
          ),
      ],
    );
  }

  Widget _row(String label, String value) => SizedBox(
    height: infoRow,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: infoPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: infoLabelWidth + 12,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.callout(color: _c.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.callout(color: _c.textPrimary),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _content(InfoSection section) {
    final entry = widget.entry;
    switch (section) {
      case InfoSection.general:
        return Column(
          children: [
            _row(l10n.kind, widget.kind),
            if (entry.isDirectory)
              _row(l10n.size, _sizeLine(entry))
            else
              _row(
                l10n.size,
                l10n.sizeOnDisk(
                  entry.size,
                  formatSize(
                    Entry(
                      name: '',
                      path: '',
                      isDirectory: false,
                      size: _stat.onDisk,
                      modified: entry.modified,
                    ),
                  ),
                ),
              ),
            _row(l10n.location, parentOf(entry.path) ?? '/'),
            _row(l10n.created, _date(_stat.created)),
            _row(l10n.modified, _date(entry.modified)),
          ],
        );
      case InfoSection.more:
        final mime = widget.mime;
        final image = mime != null && mime.startsWith('image/');
        return Column(
          children: [
            if (!entry.isDirectory) _row(l10n.infoContentType, mime ?? '--'),
            if (image)
              _row(l10n.infoDimensions, switch (_dimensions) {
                final d? => l10n.infoPixels(d.width, d.height),
                null => '--',
              }),
            _row(l10n.infoLastOpened, _date(_stat.accessed)),
          ],
        );
      case InfoSection.name:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: infoPadding),
          child: AmalfiTextField(
            key: const ValueKey('name field'),
            controller: _name,
            focusNode: _nameFocus,
            width: infoWidth - 2 * infoPadding,
            semanticLabel: l10n.infoNameExtension,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) widget.onRename(value.trim());
            },
          ),
        );
      case InfoSection.comments:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: infoPadding),
          child: AmalfiTextArea(
            key: const ValueKey('comment field'),
            controller: _comment,
            focusNode: _commentFocus,
            size: const Size(infoWidth - 2 * infoPadding, 64),
            semanticLabel: l10n.infoComments,
          ),
        );
      case InfoSection.openWith:
        return _row(l10n.app, widget.openWith ?? l10n.none);
      case InfoSection.preview:
        return Center(
          child: SizedBox(
            width: 128,
            height: 128,
            child: EntryIcon(entry: entry, side: 128, env: widget.env),
          ),
        );
      case InfoSection.permissions:
        return Column(
          children: [
            for (final (label, shift) in [
              (l10n.ownerMe(_stat.owner.isEmpty ? '?' : _stat.owner), 6),
              (_stat.group.isEmpty ? l10n.groupFallback : _stat.group, 3),
              (l10n.everyone, 0),
            ])
              _permission(label, shift),
          ],
        );
    }
  }

  Widget _permission(String who, int shift) {
    final current = privilegeOf(_stat.mode, shift);
    return SizedBox(
      height: infoRow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: infoPadding),
        child: Row(
          children: [
            Expanded(
              child: Text(
                who,
                style: AmalfiType.callout(color: _c.textPrimary),
              ),
            ),
            // A click moves to the next privilege, applied on disk right away (R11.4).
            GestureDetector(
              key: ValueKey('privilege $shift'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                const order = [
                  Privilege.readWrite,
                  Privilege.readOnly,
                  Privilege.none,
                ];
                final next = order[(order.indexOf(current) + 1) % order.length];
                final mode = withPrivilege(_stat.mode, shift, next);
                try {
                  final r = Process.runSync('chmod', [
                    mode.toRadixString(8),
                    widget.entry.path,
                  ]);
                  if (r.exitCode == 0) {
                    setState(() => _stat = StatDetails.of(widget.entry.path));
                  }
                } on ProcessException {
                  // Without chmod it stays as it was.
                }
              },
              child: Text(
                privilegeLabel(current),
                style: AmalfiType.callout(color: _c.accentAmalfi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
