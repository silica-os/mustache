// The icon view (MU-21, docs/spec/icon-view.md for the behaviour; kit `Apps/Mustache/Tile`, `Tile
// Selected`, components.md for the look): tiles 104 wide (the icon size plus 40) with the icon above its
// name, 16 pt apart, left aligned from the content padding of 20; a selected tile has a sunken
// background 12 pt wider than the icon on each side and an accent capsule behind the name.
//
// Grid: the x pitch is the tile plus the gap, the first tile at 20 from the left and the top; the
// y pitch is the tile height (the icon size plus 40) plus the gap. Labels on at most two lines.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'folder_customize.dart' show FolderIconAnchor;
import 'folder_icons.dart';
import 'folder_style.dart';
import 'icon_arrange.dart';
import 'model.dart';
import 'tags.dart';

/// The default icon size and the text size (spec/icon-view.md).
const double defaultIconSide = 64;
const double defaultLabelSize = 12;

/// The content padding, the gap between tiles and the tile around an icon of `side`: 20 each side
/// of the icon plus the label; at least 104 wide.
const double iconGridPadding = 20;
const double iconGridGap = 16;
double iconTileWidth(double side) => math.max(104, side + 40);
double iconTileHeight(double side) => side + 40;

/// The selected icon background: 12 wider than the icon on each side, 4 taller (kit `Tile
/// Selected`: 88 × 68 around a 64 icon, radius 8).
const double iconSelectionPadX = 12;
const double iconSelectionPadBottom = 4;
const double iconSelectionRadius = 8;

/// The name capsule (kit: 88 × 20, radius 10, 8 below the icon): 4 pt above and below the lines of
/// 16 pt, 8 pt either side of the text, at least 88 wide.
const double labelLine = 16;
const double labelCapsuleExtra = 4;
const double labelRadius = 10;
const double labelPad = 8;
const double labelMinWidth = 88;
const double labelGap = 8;

/// Image thumbnails take ~89% of the icon size, ~3 pt corners (spec/icon-view.md).
const double thumbnailRatio = 0.89;

const double thumbnailRadius = 3;

/// Selection colors: Amalfi tokens.
@immutable
class IconViewColors {
  const IconViewColors(this.tokens);

  final AmalfiColors tokens;

  Color get iconSelection => tokens.surfaceSunken;
  Color get label => tokens.textPrimary;
  Color get labelSelected => tokens.textOnAccent;
  Color get capsule => tokens.accentAmalfi;

  /// A window that is not active, or tiles being dragged (Assumption: not measured).
  Color get capsuleInactive => tokens.lineBorder;
  Color get labelSelectedInactive => tokens.textPrimary;

  static IconViewColors of(BuildContext context) =>
      IconViewColors(AmalfiTheme.of(context).colors);
}

/// The grid geometry for a content width.
@immutable
class IconGrid {
  const IconGrid({
    required this.side,
    required this.columns,
    required this.pitchX,
    required this.pitchY,
    required this.left,
    required this.top,
  });

  /// Icon size.
  final double side;
  final int columns;
  final double pitchX;
  final double pitchY;

  /// The first cell's x pitch origin (half a gap left of the first tile) and the top of the first
  /// icon.
  final double left;
  final double top;

  /// The width of a tile.
  double get tile => pitchX - iconGridGap;

  /// The x center of cell `column`.
  double centerX(int column) => left + pitchX * (column + 0.5);

  /// The top of the icon of row `row`.
  double iconTop(int row) => top + pitchY * row;

  /// The cell under a point (null outside the cells taken by `count` items).
  int? indexAt(Offset p, int count) {
    if (p.dx < left || p.dy < top) return null;
    final column = ((p.dx - left) / pitchX).floor();
    final row = ((p.dy - top) / pitchY).floor();
    if (column < 0 || column >= columns) return null;
    final index = row * columns + column;
    return index < count ? index : null;
  }
}

/// The x pitch: the tile plus the gap.
double minIconPitch({
  double side = defaultIconSide,
  double text = defaultLabelSize,
}) => iconTileWidth(side) + iconGridGap;

/// The grid for `width` pt of content: tiles left aligned from the padding, the gap between them.
IconGrid iconGrid(
  double width, {
  double side = defaultIconSide,
  double text = defaultLabelSize,
}) {
  final pitch = minIconPitch(side: side, text: text);
  final columns = math.max(
    1,
    ((width - 2 * iconGridPadding + iconGridGap) / pitch).floor(),
  );
  return IconGrid(
    side: side,
    columns: columns,
    pitchX: pitch,
    pitchY: iconTileHeight(side) + iconGridGap,
    left: iconGridPadding - iconGridGap / 2,
    top: iconGridPadding,
  );
}

/// The maximum width of a label: ~104 pt at text 12 (MU-21: "Beta con un nome" fits,
/// "configurazione.jso" does not), proportional to the text size.
double labelMaxWidth(double text) => 104 * text / defaultLabelSize;

/// The label lines: at most two; the first wraps at spaces, and inside a word only if the word does
/// not fit; the second, if it does not fit, is truncated in the middle (R4.5).
List<String> labelLines(String name, double maxWidth, TextStyle style) {
  double widthOf(String s) {
    final painter = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  if (widthOf(name) <= maxWidth) return [name];
  // The first line: how many characters fit; it breaks at the last space that fits, and inside a
  // word only if the first word alone does not fit (MU-21: "barre / colorate.mov",
  // "configurazione.js / on").
  var cut = 1;
  while (cut < name.length && widthOf(name.substring(0, cut + 1)) <= maxWidth) {
    cut++;
  }
  final space = name.lastIndexOf(' ', cut);
  if (space > 0) cut = space + 1;
  final first = name.substring(0, cut).trimRight();
  var rest = name.substring(cut).trimLeft();
  if (rest.isEmpty) return [first];
  if (widthOf(rest) > maxWidth) {
    // Middle truncation: characters around the middle are removed until it fits.
    var keep = rest.length - 1;
    String middle(int n) {
      final head = (n + 1) ~/ 2;
      final tail = n - head;
      // No spaces around the "…" (MU-21: "molto lu…colonna").
      return '${rest.substring(0, head).trimRight()}…'
          '${rest.substring(rest.length - tail).trimLeft()}';
    }

    while (keep > 1 && widthOf(middle(keep)) > maxWidth) {
      keep--;
    }
    rest = middle(keep);
  }
  return [first, rest];
}

/// The rubber band: the soft accent with a 1 pt accent outline, square corners (Assumption: not
/// measured, the kit has no rubber band).

/// The movement that turns a press on the background into a rubber band.
const double bandThreshold = 1;

/// Autoscroll past the edge: ~38.5 pt/s for each pt beyond (R7.4).
const double autoScrollPerPoint = 38.5;

class IconView extends StatefulWidget {
  const IconView({
    super.key,
    required this.entries,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    required this.onBackground,
    this.onContext,
    this.wrapItem,
    this.active = true,
    this.side = defaultIconSide,
    this.text = defaultLabelSize,
    this.env,
    this.controller,
    this.renaming,
    this.renameBuilder,
    this.onRubberBand,
    this.onNamePress,
    this.tagsOf,
    this.positions,
    this.moveDuration = Duration.zero,
  });

  /// Free positions (sort "None", R4.7): the icon's center x and top y in the content, by path.
  /// Null: the grid stretches to the width and reflows with it. With positions the cells keep the
  /// fixed pitch of [FreeGrid], resizing the window moves nothing and the content scrolls in both
  /// directions when it does not fit (mustache#4).
  final Map<String, Offset>? positions;

  /// How long icons take to reach new positions (Clean Up animates, R4.8; drops do not).
  final Duration moveDuration;

  /// The tags of an item: the dots before the name, on the first line.
  final List<String> Function(Entry entry)? tagsOf;

  /// The rubber band: the touched items, live; `done` on release.
  final void Function(Set<String> paths, {required bool done})? onRubberBand;

  /// A press on an item's name, heard before the cell's own press (slow-click rename, R8).
  final ValueChanged<Entry>? onNamePress;

  final List<Entry> entries;
  final Set<String> selected;
  final ValueChanged<Entry> onTap;
  final ValueChanged<Entry> onOpen;

  /// Click on the background: clears the selection.
  final VoidCallback onBackground;

  /// Wraps every cell (dragging, drop target).
  final Widget Function(Entry entry, Widget child)? wrapItem;

  /// Secondary click on an item (or on the background, null), at the global position.
  final void Function(Entry? entry, Offset position)? onContext;
  final bool active;
  final double side;
  final double text;

  /// The environment where silica-icons is found (tests).
  final Map<String, String>? env;
  final ScrollController? controller;

  /// The item being renamed: instead of the label, the field built by `renameBuilder` (at most as
  /// wide as the cell).
  final String? renaming;
  final Widget Function(Entry entry, double maxWidth)? renameBuilder;

  @override
  State<IconView> createState() => _IconViewState();
}

class _IconViewState extends State<IconView> {
  late final ScrollController _scroll = widget.controller ?? ScrollController();
  final ScrollController _hScroll = ScrollController();
  Offset? _bandStart;
  Offset? _bandEnd;

  /// The press that may become a rubber band (not on a cell) and where it was.
  int? _bandPointer;
  Offset? _bandFrom;

  /// A cell took the press being dispatched (cells hear it before the background).
  bool _cellPressed = false;

  /// Where the pointer is relative to the view (for edge autoscroll).
  double _pointerY = 0;
  double _viewHeight = 0;
  Timer? _auto;
  IconGrid? _grid;

  List<Entry> get entries => widget.entries;
  Set<String> get selected => widget.selected;
  ValueChanged<Entry> get onTap => widget.onTap;
  ValueChanged<Entry> get onOpen => widget.onOpen;
  VoidCallback get onBackground => widget.onBackground;
  Widget Function(Entry entry, Widget child)? get wrapItem => widget.wrapItem;
  void Function(Entry? entry, Offset position)? get onContext =>
      widget.onContext;
  bool get active => widget.active;
  double get side => widget.side;
  double get text => widget.text;
  Map<String, String>? get env => widget.env;
  String? get renaming => widget.renaming;
  Widget Function(Entry entry, double maxWidth)? get renameBuilder =>
      widget.renameBuilder;

  @override
  void dispose() {
    _auto?.cancel();
    if (widget.controller == null) _scroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  /// The icon's center x and top y of item `index`, in the content.
  Offset _place(IconGrid grid, int index) {
    final free = widget.positions?[entries[index].path];
    if (free != null) return free;
    return Offset(
      grid.centerX(index % grid.columns),
      grid.iconTop(index ~/ grid.columns),
    );
  }

  /// The rectangle of a cell (icon background and label), in the content.
  Rect _cellRect(IconGrid grid, int index) {
    final at = _place(grid, index);
    final cx = at.dx;
    final tile = grid.tile;
    return Rect.fromLTWH(
      cx - tile / 2 + 8,
      at.dy,
      tile - 16,
      side + labelGap + labelLine + labelCapsuleExtra,
    );
  }

  void _band({required bool done}) {
    final grid = _grid;
    final start = _bandStart;
    final end = _bandEnd;
    if (grid == null || start == null || end == null) return;
    final rect = Rect.fromPoints(start, end);
    widget.onRubberBand?.call({
      for (var i = 0; i < entries.length; i++)
        if (_cellRect(grid, i).overlaps(rect)) entries[i].path,
    }, done: done);
  }

  /// Past the top or bottom edge the view scrolls, faster the further out.
  void _autoScroll() {
    _auto ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final over = _pointerY < 0
          ? _pointerY
          : _pointerY > _viewHeight
          ? _pointerY - _viewHeight
          : 0.0;
      if (over == 0 || !_scroll.hasClients || _bandStart == null) return;
      final pos = _scroll.position;
      final next = (pos.pixels + over * autoScrollPerPoint * 0.016).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if (next == pos.pixels) return;
      final moved = next - pos.pixels;
      _scroll.jumpTo(next);
      setState(() => _bandEnd = _bandEnd?.translate(0, moved));
      _band(done: false);
    });
  }

  void _bandDownAt(PointerDownEvent e) {
    final onCell = _cellPressed;
    _cellPressed = false;
    if (onCell ||
        widget.onRubberBand == null ||
        e.buttons & kPrimaryButton == 0) {
      return;
    }
    _bandPointer = e.pointer;
    _bandFrom = e.localPosition;
  }

  void _bandMove(PointerMoveEvent e) {
    final from = _bandFrom;
    if (e.pointer != _bandPointer || from == null) return;
    if (_bandStart == null) {
      // A click that does not move is not a rubber band.
      if ((e.localPosition - from).distance < bandThreshold) return;
      setState(() => _bandStart = from);
      _autoScroll();
    }
    setState(() => _bandEnd = e.localPosition);
    _pointerY = e.localPosition.dy - (_scroll.hasClients ? _scroll.offset : 0);
    _band(done: false);
  }

  void _bandRelease(int pointer, {required bool done}) {
    if (pointer != _bandPointer) return;
    _bandPointer = null;
    _bandFrom = null;
    _auto?.cancel();
    _auto = null;
    if (_bandStart == null) return;
    _band(done: done);
    setState(() => _bandStart = _bandEnd = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = IconViewColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final free = widget.positions != null;
        final fixed = FreeGrid.of(side: side, text: text);
        final grid = free
            ? IconGrid(
                side: side,
                columns: fixed.columnsFor(constraints.maxWidth),
                pitchX: fixed.pitchX,
                pitchY: fixed.pitchY,
                left: fixed.left,
                top: fixed.top,
              )
            : iconGrid(constraints.maxWidth, side: side, text: text);
        var height = 0.0;
        var width = constraints.maxWidth;
        if (free) {
          // The content reaches the farthest icon, plus the margins.
          for (var i = 0; i < entries.length; i++) {
            final at = _place(grid, i);
            height = math.max(height, at.dy + grid.pitchY);
            width = math.max(width, at.dx + grid.pitchX / 2 + grid.left);
          }
        } else {
          final rows = (entries.length / grid.columns).ceil();
          height = rows == 0 ? 0.0 : grid.iconTop(rows - 1) + grid.pitchY;
        }
        _grid = grid;
        // Edge autoscroll counts from the top of the view.
        _viewHeight = constraints.maxHeight;
        final band = _bandStart == null || _bandEnd == null
            ? null
            : Rect.fromPoints(_bandStart!, _bandEnd!);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBackground,
          onSecondaryTapDown: (d) => onContext?.call(null, d.globalPosition),
          child: SingleChildScrollView(
            controller: _scroll,
            child: _horizontal(
              free: free,
              child: Listener(
                // From the background: the rubber band. Raw pointer events, not a gesture: a press
                // on a cell (its own drag) never starts it.
                behavior: HitTestBehavior.translucent,
                onPointerDown: _bandDownAt,
                onPointerMove: _bandMove,
                onPointerUp: (e) => _bandRelease(e.pointer, done: true),
                onPointerCancel: (e) => _bandRelease(e.pointer, done: true),
                child: SizedBox(
                  width: width,
                  height: math.max(height, constraints.maxHeight),
                  child: Stack(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        _cell(context, grid, i, colors),
                      if (band != null)
                        Positioned.fromRect(
                          rect: band,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: const ValueKey('rubber band'),
                              decoration: BoxDecoration(
                                color: colors.tokens.accentAmalfiSoft,
                                border: Border.all(
                                  color: colors.tokens.accentAmalfi,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// With free positions the content can be wider than the view: it scrolls sideways too.
  Widget _horizontal({required bool free, required Widget child}) => free
      ? SingleChildScrollView(
          key: const ValueKey('icon view horizontal scroll'),
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: child,
        )
      : child;

  Widget _cell(
    BuildContext context,
    IconGrid grid,
    int index,
    IconViewColors c,
  ) {
    final entry = entries[index];
    final isSelected = selected.contains(entry.path);
    final at = _place(grid, index);
    final cx = at.dx;
    final iconTop = at.dy;
    final tile = grid.tile;
    final style = AmalfiType.callout(
      color: isSelected
          ? (active ? c.labelSelected : c.labelSelectedInactive)
          : c.label,
    );
    final tags = widget.tagsOf?.call(entry) ?? const <String>[];
    final builder = renameBuilder;
    final field = entry.path == renaming && builder != null
        ? builder(entry, tile - 4)
        : null;
    final lines = field != null
        ? const ['']
        : labelLines(
            entry.name,
            math.min(labelMaxWidth(widget.text), grid.pitchX - 2 * labelPad),
            style,
          );
    final capsuleHeight = labelLine * lines.length + labelCapsuleExtra;
    final labelTop = side + labelGap;
    final bgWidth = side + 2 * iconSelectionPadX;
    return AnimatedPositioned(
      key: ValueKey('cell ${entry.path}'),
      duration: widget.moveDuration,
      curve: Curves.decelerate,
      left: cx - tile / 2,
      top: iconTop,
      width: tile,
      height: labelTop + capsuleHeight,
      // Selection on press, right away (not after the double-click wait).
      child: (wrapItem ?? (_, Widget child) => child)(
        entry,
        Listener(
          onPointerDown: (_) {
            _cellPressed = true;
            onTap(entry);
          },
          child: GestureDetector(
            key: ValueKey(entry.path),
            // The whole tile is the item (the kit's tile frame): a click anywhere in it is not a click
            // on the background.
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            onDoubleTap: () => onOpen(entry),
            onSecondaryTapDown: (d) => onContext?.call(entry, d.globalPosition),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isSelected)
                  Positioned(
                    left: (tile - bgWidth) / 2,
                    top: 0,
                    width: bgWidth,
                    height: side + iconSelectionPadBottom,
                    child: DecoratedBox(
                      key: ValueKey('icon background ${entry.path}'),
                      decoration: ShapeDecoration(
                        color: c.iconSelection,
                        shape: AmalfiSmoothBorder(radius: iconSelectionRadius),
                      ),
                    ),
                  ),
                Positioned(
                  left: (tile - side) / 2,
                  top: 0,
                  width: side,
                  height: side,
                  child: EntryIcon(entry: entry, side: side, env: env),
                ),
                if (field != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: labelTop - 2,
                    child: Center(child: field),
                  )
                else
                  // The capsule may extend a few pt beyond the cell: the lines are already broken
                  // by `labelLines`, they do not wrap again here.
                  Positioned(
                    left: -labelPad,
                    right: -labelPad,
                    top: labelTop,
                    height: capsuleHeight,
                    child: Center(
                      child: Listener(
                        // A press on the name (not the icon) may become a slow click (R8).
                        onPointerDown: (_) => widget.onNamePress?.call(entry),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: labelMinWidth,
                          ),
                          child: DecoratedBox(
                            key: ValueKey('name ${entry.path} 0'),
                            decoration: ShapeDecoration(
                              color: isSelected
                                  ? (active ? c.capsule : c.capsuleInactive)
                                  : null,
                              shape: AmalfiSmoothBorder(radius: labelRadius),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: labelPad,
                                vertical: labelCapsuleExtra / 2,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < lines.length; i++)
                                    SizedBox(
                                      height: labelLine,
                                      child: i == 0 && tags.isNotEmpty
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TagDots(
                                                  tags: tags,
                                                  pitch: iconTagPitch,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  lines[i],
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  style: style,
                                                ),
                                              ],
                                            )
                                          : Text(
                                              lines[i],
                                              maxLines: 1,
                                              softWrap: false,
                                              textAlign: TextAlign.center,
                                              style: style,
                                            ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The extensions whose thumbnail is shown.
const Set<String> thumbnailExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp'};

bool hasThumbnail(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 &&
      thumbnailExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// The icon of an item: folder (with the symbol of special folders), image thumbnail, or the type
/// icon with the silica-icons rules; with badges (alias, unreadable).
class EntryIcon extends StatelessWidget {
  const EntryIcon({
    super.key,
    required this.entry,
    required this.side,
    this.env,
  });

  final Entry entry;
  final double side;
  final Map<String, String>? env;

  /// Badges per path and modification date: computed once, not on every paint (folders with
  /// thousands of files, MU-24).
  static final Map<String, Set<IconBadge>> _cache = {};

  Set<IconBadge> _resolve() {
    final key = '${entry.path}\u0000${entry.modified.microsecondsSinceEpoch}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 20000) _cache.clear();
    return _cache[key] = badgesOf(entry.path);
  }

  @override
  Widget build(BuildContext context) {
    if (hasThumbnail(entry.name) && !entry.isDirectory) {
      return _Thumbnail(entry.path, side);
    }
    // Folders and documents: the silica-icons canvas is the whole size (silica-icons 0.2, measured
    // on MU-21: folder 0.922 × 0.734, sheet 0.668 × 0.883 of the canvas).
    return _icon(side);
  }

  Widget _icon(double side) {
    final badges = _resolve();
    if (entry.isDirectory) {
      // Colour and symbol live on the folder: redrawn when they change (folder_style.dart).
      return ListenableBuilder(
        listenable: folderStyles,
        builder: (context, _) => FolderIconAnchor(
          path: entry.path,
          child: FolderEmoji(
            emoji: folderStyles.look(entry.path).emoji,
            side: side,
            child: SilicaIcon(
              folderSource(entry.path),
              side: side,
              badges: badges,
              env: env,
            ),
          ),
        ),
      );
    }
    return SilicaIcon(
      ServiceSource(Uri.file(entry.path)),
      side: side,
      badges: badges,
      env: env,
    );
  }
}

/// The thumbnail of an image: ~89% of the size, 3 pt corners, soft shadow below; if the image
/// cannot be read, the type icon.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail(this.path, this.side);
  final String path;
  final double side;

  @override
  Widget build(BuildContext context) {
    final box = side * thumbnailRatio;
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return Center(
      child: ConstrainedBox(
        // Wide: the image keeps its proportions inside the box, and shadow and corners follow the
        // image, not the box.
        constraints: BoxConstraints.loose(Size(box, box)),
        child: Image.file(
          File(path),
          cacheWidth: (box * ratio).round(),
          frameBuilder: (context, child, frame, _) => frame == null
              ? const SizedBox.shrink()
              : Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 7,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(thumbnailRadius),
                      child: child,
                    ),
                  ),
                ),
          errorBuilder: (context, error, stack) {
            return SilicaIcon(ServiceSource(Uri.file(path)), side: side);
          },
        ),
      ),
    );
  }
}
