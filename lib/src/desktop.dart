// The desktop (silica-desktop#147, docs/spec/desktop.md, MU-90, R15.*): `mustache --desktop` draws
// the user's desktop folder as icons on a full-screen surface of the bottom layer, above the
// wallpaper and below the windows; Ossido keeps the process running and makes Mustache the
// frontmost app when the desktop is clicked.
//
// Icons are 96 pt; the first one's right edge is 22 pt from the screen's right edge (its cell 8 pt), its top 40 pt
// from the top; the grid pitch is 124 × 148 and new icons fill it top to bottom, then towards the
// left (R15.1). Labels are white and bold with a soft shadow, the same in light and dark. With
// Sort By › None icons keep free positions (stored like the windows' ones, keyed by the desktop
// folder); Clean Up moves the off-grid ones to the nearest free cell; Use Stacks groups items by
// kind (R15.2), a stack opening in place (R15.3).
//
// Selecting paints a square behind the icon and a capsule behind its name, outside the layout.
// Dragging hands the files to Ossido with an image of the icons as drawn, translucent, grabbed
// where the pointer pressed (MU-40); the icons stay in place, dimmed, until the drag ends.
//
// The context menu is drawn by the shell's menu bar (the desktop is below the windows, its menu
// is not): the desktop announces the click (`desktopmenu` = "x y desktop" or "x y items") and its
// state (`desktop.state`), and runs the items the menu sends back (`desktop.action`).

import 'external.dart';
import 'folder_style.dart';
import 'folder_watch.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'apps.dart';
import 'drag.dart' show composeDragImage, startFileDrag;
import 'icon_arrange.dart';
import 'icon_view.dart' show EntryIcon, labelLines;
import 'menu_scope.dart';
import 'menus.dart';
import 'model.dart';
import 'operations.dart';
import 'rename_field.dart';
import 'settings.dart';
import 'sounds.dart';
import 'tags.dart';
import 'xattr.dart' as xattr;

/// The desktop's icon size, label size and grid (MU-90).
const double desktopIconSide = 96;
const double desktopLabelSize = 13;
const double desktopPitchX = 124;
const double desktopPitchY = 148;
const double desktopRight = 22;
const double desktopTop = 40;

/// The space kept free at the bottom for the Dock: 8 rows on a 1440 pt display (R15.1).
const double desktopBottom = 84;

/// The selection around the icon (kit `Apps/Mustache/Desktop`): a rounded square of 104 × 104,
/// 4 pt around the 96 pt icon, radius 16, black 30 % inside a 2 pt light line (white 45 %), the
/// same in light and dark. It is painted behind the icon and never takes part in the layout:
/// selecting moves neither the icon nor its name.
const double desktopSelectionPad = 4;
const double desktopSelectionSide = desktopIconSide + 2 * desktopSelectionPad;
const double desktopSelectionRadius = 16;
const double desktopSelectionOutlineWidth = 2;
const Color desktopSelectionFill = Color(0x4D000000);
const Color desktopSelectionOutline = Color(0x73FFFFFF);

/// The selected name's capsule (kit): one capsule hugging the label, radius 10, 6 pt of side
/// padding and 2 pt above and below the lines, `Accent/Amalfi` with white text; light grey
/// `#d0d0d0` with dark text while the desktop is not the active surface (a window is key), the
/// square unchanged.
const Color desktopCapsuleInactive = Color(0xFFD0D0D0);
const Color desktopCapsuleInactiveText = Color(0xFF1D1D1F);
const double desktopCapsulePad = 6;
const double desktopCapsulePadY = 2;
const double desktopCapsuleRadius = 10;

/// The capsule's top is 8 pt below the icon, the name's text 10 pt (kit); one line is 18 pt (Headline
/// 13 / 18), at most two, the middle of a longer name truncated.
const double desktopLabelGap = 8;
const double desktopLabelLine = 18;

/// The widest a line of the name gets.
const double desktopLabelWidth = desktopPitchX - 12;

/// The rubber band on the desktop (kit): square corners, a 1 pt line, white 10 % fill and 32 % line
/// in dark, black 10 % and 33 % in light.
const Color desktopBandFill = Color(0x1AFFFFFF);
const Color desktopBandBorder = Color(0x52FFFFFF);
const Color desktopBandFillLight = Color(0x1A000000);
const Color desktopBandBorderLight = Color(0x54000000);

/// The drag threshold on the desktop (R7.7: 4–5 pt).
const double desktopDragThreshold = 4.5;

/// The dragged icons left in place while the image travels: dimmed (provisional, DESKTOP-SEL).
const double desktopDragDim = 0.5;

/// An icon that has to reach its cell after a drop (an ordered desktop, a place off the screen)
/// travels there decelerating in ~250 ms (R15.7).
const Duration desktopSettle = Duration(milliseconds: 250);

/// The count badge of a drag with several items ([dragBadgeSide], 20 pt): its center sits below
/// and right of the pointer (DESKTOP-SEL: +9…+28 pt across, +11…+30 pt down).
const Offset desktopBadgeFromPointer = Offset(19, 20);

/// After a drop on free desktop (no snapping) the drag image, badge included, fades out in
/// ~175 ms and the selection (square and capsule) is back ~275 ms after the release.
const Duration desktopDropFade = Duration(milliseconds: 175);
const Duration desktopDropSelect = Duration(milliseconds: 275);

/// The double click: a second press within this time on the same icon opens it.
const Duration desktopDoubleClick = Duration(milliseconds: 500);

/// The desktop's grid on a screen of `size`.
@immutable
class DesktopGrid {
  const DesktopGrid(this.size);

  final Size size;

  /// Rows that fit above the Dock, at least one.
  int get rows => math.max(
    1,
    ((size.height - desktopTop - desktopBottom) / desktopPitchY).floor(),
  );

  /// The icon's center x and top y of a cell; columns count from the right.
  Offset cell(int column, int row) => Offset(
    size.width - desktopRight - desktopIconSide / 2 - column * desktopPitchX,
    desktopTop + row * desktopPitchY,
  );

  /// The cell of the n-th icon filling the grid top to bottom, then leftwards.
  (int, int) nth(int index) => (index ~/ rows, index % rows);

  /// The cell nearest to a position (never at negative indices).
  (int, int) cellOf(Offset p) => (
    math.max(
      0,
      ((size.width - desktopRight - desktopIconSide / 2 - p.dx) / desktopPitchX)
          .round(),
    ),
    math.max(0, ((p.dy - desktopTop) / desktopPitchY).round()),
  );

  bool onGrid(Offset p) {
    final (c, r) = cellOf(p);
    return (cell(c, r) - p).distance < 0.5;
  }

  /// The free cell nearest to `p`, searched in rings around its own cell, within the rows.
  Offset nearestFree(Offset p, Set<(int, int)> taken) {
    final (c0, r0) = cellOf(p);
    Offset? best;
    var bestDistance = double.infinity;
    int? foundAt;
    for (var ring = 0; ring < 1000; ring++) {
      if (foundAt != null && ring > foundAt + 1) break;
      for (var r = r0 - ring; r <= r0 + ring; r++) {
        for (var c = c0 - ring; c <= c0 + ring; c++) {
          if (c < 0 || r < 0 || r >= rows) continue;
          if ((r - r0).abs() != ring && (c - c0).abs() != ring) continue;
          if (taken.contains((c, r))) continue;
          final d = (cell(c, r) - p).distance;
          if (d < bestDistance) {
            bestDistance = d;
            best = cell(c, r);
            foundAt ??= ring;
          }
        }
      }
    }
    return best ?? cell(c0, r0);
  }

  /// The first free cell in filling order.
  Offset firstFree(Set<(int, int)> taken) {
    for (var i = 0; i < 100000; i++) {
      final (c, r) = nth(i);
      if (!taken.contains((c, r))) return cell(c, r);
    }
    return cell(0, 0);
  }

  Set<(int, int)> taken(Iterable<Offset> positions) => {
    for (final p in positions)
      if (onGrid(p)) cellOf(p),
  };
}

/// The sort orders of the desktop menu; `none` keeps free positions.
const List<String> desktopSorts = ['none', 'name', 'kind', 'modified', 'size'];

SortKey? sortKeyOf(String sort) => switch (sort) {
  'name' => SortKey.name,
  'kind' => SortKey.kind,
  'modified' => SortKey.modified,
  'size' => SortKey.size,
  _ => null,
};

/// The desktop's choices: sort order and stacks (`$XDG_STATE_HOME/mustache/desktop.json`).
class DesktopChoices {
  DesktopChoices(this.path) {
    try {
      final value = jsonDecode(File(path).readAsStringSync());
      if (value is Map) {
        final s = value['sort'];
        if (s is String && desktopSorts.contains(s)) sort = s;
        stacks = value['stacks'] == true;
      }
    } on Object {
      // Missing or damaged: the defaults.
    }
  }

  factory DesktopChoices.forUser(Map<String, String> env) {
    final home = env['HOME'] ?? '/';
    final state = env['XDG_STATE_HOME'];
    final base = state == null || state.isEmpty ? '$home/.local/state' : state;
    return DesktopChoices('$base/mustache/desktop.json');
  }

  final String path;
  String sort = 'none';
  bool stacks = false;

  void save() {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode({'sort': sort, 'stacks': stacks}));
    } on FileSystemException {
      // Lasts for this session only.
    }
  }
}

/// One icon on the desktop: an item, or a stack of the items of one kind.
@immutable
class DesktopIcon {
  const DesktopIcon.item(Entry this.entry) : stack = null, members = const [];
  const DesktopIcon.stack(String this.stack, this.members) : entry = null;

  final Entry? entry;
  final String? stack;
  final List<Entry> members;

  /// The key it is stored and selected by: the item's name or the stack's kind.
  String get key => entry?.name ?? 'stack:$stack';
  String get label => entry?.name ?? stack ?? '';
}

/// The icons with stacks on (R15.2): a kind with one item stays a single icon; the stacks first,
/// by kind, then the single items in `order`.
List<DesktopIcon> groupStacks(
  List<Entry> order,
  String Function(Entry) kindOf,
) {
  final groups = <String, List<Entry>>{};
  for (final e in order) {
    (groups[kindOf(e)] ??= []).add(e);
  }
  final kinds = groups.keys.toList()..sort();
  return [
    for (final k in kinds)
      if ((groups[k]?.length ?? 0) > 1) DesktopIcon.stack(k, groups[k] ?? []),
    for (final e in order)
      if ((groups[kindOf(e)]?.length ?? 0) <= 1) DesktopIcon.item(e),
  ];
}

/// Where each icon goes. With a sort order (or stacks) they fill the grid in order; an open
/// stack's items take the cells right after it (R15.3, R15.8). With "None" each keeps its stored
/// position and new ones take the first free cells (R15.4).
Map<String, Offset> layoutDesktop(
  List<DesktopIcon> icons,
  DesktopGrid grid, {
  required bool free,
  Map<String, Offset> stored = const {},
  String? openStack,
}) {
  final result = <String, Offset>{};
  if (!free) {
    var i = 0;
    for (final icon in icons) {
      final (c, r) = grid.nth(i++);
      result[icon.key] = grid.cell(c, r);
      if (icon.stack != null && icon.key == openStack) {
        for (final m in icon.members) {
          final (mc, mr) = grid.nth(i++);
          result[m.name] = grid.cell(mc, mr);
        }
      }
    }
    return result;
  }
  for (final icon in icons) {
    if (stored[icon.key] case final p?) result[icon.key] = p;
  }
  final taken = grid.taken(result.values);
  for (final icon in icons) {
    if (result.containsKey(icon.key)) continue;
    final p = grid.firstFree(taken);
    taken.add(grid.cellOf(p));
    result[icon.key] = p;
  }
  return result;
}

/// Clean Up on the desktop: each off-grid icon to the nearest free cell, in reading order; the
/// others stay still (R4.8).
Map<String, Offset> cleanUpDesktop(
  Map<String, Offset> positions,
  DesktopGrid grid,
) {
  final moving =
      [
        for (final MapEntry(:key, :value) in positions.entries)
          if (!grid.onGrid(value)) key,
      ]..sort((a, b) {
        final pa = positions[a] ?? Offset.zero;
        final pb = positions[b] ?? Offset.zero;
        final dx = pb.dx.compareTo(pa.dx);
        return dx != 0 ? dx : pa.dy.compareTo(pb.dy);
      });
  final result = {...positions};
  final taken = grid.taken([
    for (final MapEntry(:key, :value) in positions.entries)
      if (!moving.contains(key)) value,
  ]);
  for (final key in moving) {
    final to = grid.nearestFree(positions[key] ?? Offset.zero, taken);
    taken.add(grid.cellOf(to));
    result[key] = to;
  }
  return result;
}

/// An action sent by the shell's menu: `desktop.action` = "<id> <serial>".
String? parseDesktopAction(String value) {
  final space = value.lastIndexOf(' ');
  if (space <= 0) return null;
  if (int.tryParse(value.substring(space + 1)) == null) return null;
  return value.substring(0, space);
}

/// The folder named by `--customize=<path>` among the process arguments (null: none).
String? customizeArgument(List<String> args) {
  for (final a in args) {
    if (a.startsWith('--customize=') && a.length > 12) return a.substring(12);
  }
  return null;
}

/// What a new window does on its own at start, asked by the Dock menu (DOCK-02).
enum LaunchAction { none, find, goToFolder, recents }

/// `--find` (the search field focused), `--go-to-folder` (the Go to Folder sheet) or `--recents`
/// (the recently used files) among the
/// process arguments; the first one wins.
LaunchAction launchActionOf(List<String> args) {
  for (final a in args) {
    if (a == '--find') return LaunchAction.find;
    if (a == '--go-to-folder') return LaunchAction.goToFolder;
    if (a == '--recents') return LaunchAction.recents;
  }
  return LaunchAction.none;
}

/// Quotes a path for `sh -c`.
String shellQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

/// The desktop folder: `XDG_DESKTOP_DIR` of `user-dirs.dirs`, else `~/Desktop`.
String desktopFolderOf(Map<String, String> env, String? userDirs) {
  final home = env['HOME'] ?? '/';
  final line = RegExp(
    r'^XDG_DESKTOP_DIR="([^"]*)"',
    multiLine: true,
  ).firstMatch(userDirs ?? '');
  final path = line?.group(1)?.replaceAll(r'$HOME', home);
  return path == null || path.isEmpty ? '$home/Desktop' : path;
}

/// The shell's channel: the desktop is a shell component (Ossido keeps it running).
const MethodChannel _shell = MethodChannel('silica/shell', JSONMethodCodec());

Future<void> _broadcast(String topic, String value) async {
  try {
    await _shell.invokeMethod<Object?>('broadcast', {
      'topic': topic,
      'value': value,
    });
  } on MissingPluginException {
    // Outside Silica: nobody draws the menu.
  } on PlatformException {
    // Not a shell component.
  }
}

Future<void> _launch(String command) async {
  try {
    final ok = await _shell.invokeMethod<bool>('launch', {'command': command});
    if (ok == true) return;
  } on MissingPluginException {
    // Outside Silica: started here instead.
  } on PlatformException {
    // Same.
  }
  try {
    await startDetached('sh', ['-c', command]);
  } on ProcessException {
    // Nothing to start it with: the click does nothing, as a missing app would.
  }
}

class DesktopView extends StatefulWidget {
  const DesktopView({
    super.key,
    required this.folder,
    required this.positions,
    required this.choices,
    this.env,
    this.kindOf,
    this.watch = true,
    this.readTags = xattr.readTags,
    this.writeTags = xattr.writeTags,
    this.places = const [],
    this.settings,
  });

  /// Settings (folders on top, colour by tag); null keeps the defaults.
  final Settings? settings;

  /// The user's folders (the Go menu opens a window on one).
  final List<Place> places;

  final String folder;
  final IconPositions positions;
  final DesktopChoices choices;
  final Map<String, String>? env;

  /// The kind of an item (stacks, Sort By › Kind); the MIME family by default.
  final String Function(Entry)? kindOf;

  /// Follows the folder's changes (off in tests).
  final bool watch;

  /// Reads and writes the tags of an item (`user.xdg.tags`); tests pass fakes.
  final List<String> Function(String path) readTags;
  final bool Function(String path, List<String> tags) writeTags;

  @override
  State<DesktopView> createState() => DesktopViewState();
}

/// A drag of desktop icons in progress (MU-40): the dragged keys, where the press was, and the
/// image on the pointer with the point of it under the pointer.
class _DesktopDrag {
  _DesktopDrag({
    required this.keys,
    required this.paths,
    required this.from,
    required this.pointer,
    required this.image,
    required this.hotspot,
  });

  final Set<String> keys;
  final Set<String> paths;
  final Offset from;
  Offset pointer;
  final ui.Image? image;
  final Offset hotspot;

  /// Outside Silica (no Ossido to take it) the image travels inside the desktop.
  bool local = false;
}

class DesktopViewState extends State<DesktopView>
    with TickerProviderStateMixin {
  List<Entry> _entries = const [];
  Map<String, Offset> _positions = const {};
  final Set<String> _selected = {};
  String? _openStack;
  String? _renaming;
  VoidCallback? _unwatch;
  StreamSubscription<SilicaDragEvent>? _drags;
  final FocusNode _focus = FocusNode(debugLabel: 'desktop');
  Size _size = Size.zero;

  /// The process' menu bar (menu_scope.dart) and whether a publication of the desktop's menus
  /// waits for the end of the frame.
  MenuHub? _menuHub;
  bool _menuQueued = false;

  // The press in progress.
  String? _pressKey;
  Offset? _pressAt;
  bool _dragging = false;
  Offset? _bandStart;
  Offset? _bandEnd;
  Set<String> _bandBase = const {};
  String? _lastClickKey;
  DateTime _lastClick = DateTime.fromMillisecondsSinceEpoch(0);

  /// The drag of icons in progress, and the last one: its drop back on the desktop may arrive
  /// after Ossido has already said the drag finished.
  _DesktopDrag? _drag;
  _DesktopDrag? _lastDrag;

  /// What each icon paints (icon and name, no selection square): the drag image is made of
  /// them.
  final Map<String, GlobalKey> _faces = {};

  /// Whether the desktop is the active surface (the capsules turn grey when it is not).
  bool _surfaceActive = _isActive(WidgetsBinding.instance.lifecycleState);
  late final AppLifecycleListener _lifecycle;

  static bool _isActive(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  /// Icons just dropped whose selection is not drawn yet, and the timer that brings it back.
  final Set<String> _unselectedYet = {};
  Timer? _reselect;

  /// The local drag image fading out after the drop (outside Silica), and where it is.
  ui.Image? _fadeImage;
  Offset _fadeAt = Offset.zero;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: desktopDropFade,
  )..addListener(() => setState(() {}));

  /// Icons travelling to their place after a drop: where each one starts.
  Map<String, Offset> _settleFrom = const {};
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: desktopSettle,
  )..addListener(() => setState(() {}));

  /// Text measures, kept: hit tests and the rubber band ask for them on every move.
  final Map<String, double> _lineWidths = {};
  final Map<String, List<String>> _lines = {};

  /// Selected keys, for tests.
  Set<String> get selected => Set.unmodifiable(_selected);

  /// Positions by key, for tests.
  Map<String, Offset> get positions => Map.unmodifiable(_positions);

  /// The keys being dragged (dimmed in place), for tests.
  Set<String> get dragged => Set.unmodifiable(_drag?.keys ?? const {});

  DesktopGrid get _grid => DesktopGrid(_size);
  bool get _free => widget.choices.sort == 'none' && !widget.choices.stacks;

  String _kind(Entry e) =>
      (widget.kindOf ?? (e) => kindLabel(e, systemMime.typeOf(e.path)))(e);

  @override
  void initState() {
    super.initState();
    Directory(widget.folder).createSync(recursive: true);
    widget.settings?.addListener(_settingsChanged);
    folderStyles.colourByTag = widget.settings?.colourFolders ?? true;
    _load();
    if (widget.watch) {
      _unwatch = folderWatcher.watch(widget.folder, (paths) {
        // A folder's colour or symbol (an attribute change) redraws its icon.
        folderStyles.invalidate(paths);
        if (mounted) _load();
      });
    }
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final active = _isActive(state);
        if (active != _surfaceActive && mounted) {
          setState(() => _surfaceActive = active);
        }
      },
    );
    _fade.addStatusListener((status) {
      if (status == AnimationStatus.completed) _dropFadeDone();
    });
    _drags = SilicaDrag.events.listen(_externalDrag);
    _shell.setMethodCallHandler((call) async {
      if (call.method == 'broadcast') {
        final args = call.arguments;
        if (args is Map && args['topic'] == 'desktop.action') {
          final id = parseDesktopAction('${args['value'] ?? ''}');
          if (id != null && mounted) runAction(id);
        }
      }
      return null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _menuHub = menuHubOf(context);
  }

  @override
  void dispose() {
    widget.settings?.removeListener(_settingsChanged);
    _menuHub?.release(this);
    _unwatch?.call();
    _drags?.cancel();
    _focus.dispose();
    _lifecycle.dispose();
    _reselect?.cancel();
    _fade.dispose();
    _fadeImage?.dispose();
    _settle.dispose();
    _drag?.image?.dispose();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    final listed = listDirectory(widget.folder).entries;
    setState(() {
      _entries = listed;
      _selected.retainAll({for (final i in _icons()) i.key, ..._memberNames()});
      _relayout();
    });
  }

  Iterable<String> _memberNames() sync* {
    for (final icon in _icons()) {
      for (final m in icon.members) {
        yield m.name;
      }
    }
  }

  /// settings.json changed: the order and the folders' colours follow.
  void _settingsChanged() {
    if (!mounted) return;
    folderStyles.colourByTag = widget.settings?.colourFolders ?? true;
    setState(_relayout);
  }

  List<DesktopIcon> _icons() {
    final key = sortKeyOf(widget.choices.sort);
    final order = key == null
        ? (_entries.toList()..sort((a, b) => naturalCompare(a.name, b.name)))
        : sortEntries(
            _entries,
            key,
            kindOf: _kind,
            foldersFirst: widget.settings?.foldersOnTopDesktop ?? false,
          );
    return widget.choices.stacks
        ? groupStacks(order, _kind)
        : [for (final e in order) DesktopIcon.item(e)];
  }

  void _relayout() {
    if (_size.isEmpty) return;
    final stored = widget.positions.of(widget.folder).icons;
    _positions = layoutDesktop(
      _icons(),
      _grid,
      free: _free,
      stored: stored,
      openStack: _openStack,
    );
    _faces.removeWhere((key, _) => !_positions.containsKey(key));
    if (_free) _store();
  }

  void _store() {
    widget.positions.put(
      widget.folder,
      FolderArrangement(free: true, icons: {..._positions}),
    );
  }

  /// The colour tags all of `items` have.
  Set<TagColor> _sharedColors(List<Entry> items) {
    if (items.isEmpty) return const {};
    final tags = [for (final e in items) widget.readTags(e.path)];
    return {
      for (final c in TagColor.values)
        if (tags.every((t) => t.any((n) => tagColor(n) == c))) c,
    };
  }

  /// A click on a dot: if all the selected items have the colour it is removed, else added (as
  /// in the file manager's window).
  void _toggleTag(TagColor color) {
    final items = _selection;
    if (items.isEmpty) return;
    bool has(List<String> tags) => tags.any((t) => tagColor(t) == color);
    final all = {for (final e in items) e.path: widget.readTags(e.path)};
    final remove = all.values.every(has);
    for (final MapEntry(key: path, value: tags) in all.entries) {
      final next = [...tags];
      if (remove) {
        next.removeWhere((t) => tagColor(t) == color);
      } else if (!has(next)) {
        next.add(tagName(color));
      }
      // A colour tag tints a folder.
      if (widget.writeTags(path, next)) folderStyles.invalidate([path]);
    }
  }

  /// Customize Folder…: a window of the file manager with Get Info on that section.
  void _customize() {
    final items = _selection;
    if (items.length != 1 || !items.single.isDirectory) return;
    final app = AppRegistry.load(
      env: widget.env,
      mime: systemMime,
    ).apps['dev.frascella.Mustache.desktop'];
    final args = app == null ? const <String>[] : execArguments(app, const []);
    // The Exec line runs the embedder (silica-app), which rejects unknown arguments: those for the
    // Dart app go after `--dart-arg`. The plain `mustache` fallback reads them directly.
    _launch(
      [
        ...(args.isEmpty ? const ['mustache'] : [...args, '--dart-arg']),
        '--customize=${items.single.path}',
      ].map(shellQuote).join(' '),
    );
  }

  void _announce() {
    final items = _selection;
    _broadcast(
      'desktop.state',
      jsonEncode({
        'stacks': widget.choices.stacks,
        'sort': widget.choices.sort,
        'selected': _selected.length,
        // The colour tags all the selected items have (the dots of the menu show them checked),
        // and whether the selection is one folder (Customize Folder…).
        'tags': [for (final c in _sharedColors(items)) c.name],
        'folder': items.length == 1 && items.single.isDirectory,
      }),
    );
  }

  /// The items behind the selected keys (a stack stands for its members).
  List<Entry> get _selection {
    final byName = {for (final e in _entries) e.name: e};
    final out = <Entry>[];
    for (final icon in _icons()) {
      if (!_selected.contains(icon.key)) continue;
      if (icon.entry case final e?) out.add(e);
      out.addAll(icon.members);
    }
    for (final k in _selected) {
      if (byName[k] case final e? when !out.contains(e)) out.add(e);
    }
    return out;
  }

  /// An action of the desktop menu or of a shortcut.
  void runAction(String id) {
    final folder = widget.folder;
    switch (id) {
      case 'newFolder':
        final made = createFolder(folder).path;
        if (made != null) {
          _load();
          setState(() {
            _selected
              ..clear()
              ..add(displayName(made));
            _renaming = displayName(made);
          });
        }
      case 'stacks':
        widget.choices
          ..stacks = !widget.choices.stacks
          ..save();
        _openStack = null;
        setState(_relayout);
      case 'cleanUp':
        if (!_free) return;
        setState(() => _positions = cleanUpDesktop(_positions, _grid));
        _store();
      case 'open':
        _open(_selection);
      case 'trash':
        final trash = Trash.forUser(widget.env ?? Platform.environment);
        var trashed = false;
        for (final e in _selection) {
          trashed |= trash.put(e.path).error == null;
        }
        // As the icons leave the desktop (FILE-SOUNDS).
        if (trashed) unawaited(playUiSound(UiSound.trashMove));
        _selected.clear();
        _load();
      case 'rename':
        final items = _selection;
        if (items.length == 1) setState(() => _renaming = items.single.name);
      case 'duplicate':
        var duplicated = false;
        for (final e in _selection) {
          duplicated |= duplicate(e.path).error == null;
        }
        // The copy is made: the move/copy sound (FILE-SOUNDS).
        if (duplicated) unawaited(playUiSound(UiSound.fileTransfer));
        _load();
      case 'customize':
        _customize();
      default:
        if (id.startsWith('tag:')) {
          final color = TagColor.values
              .where((c) => c.name == id.substring(4))
              .firstOrNull;
          if (color != null) _toggleTag(color);
        } else if (id.startsWith('sort:')) {
          final sort = id.substring(5);
          if (!desktopSorts.contains(sort)) return;
          widget.choices
            ..sort = sort
            ..save();
          setState(_relayout);
        } else if (id.startsWith('cleanUpBy:')) {
          final key = sortKeyOf(id.substring(10));
          if (key == null) return;
          // Lays every icon out in that order, then keeps them free (Sort By › None).
          final order = sortEntries(
            _entries,
            key,
            kindOf: _kind,
            foldersFirst: widget.settings?.foldersOnTopDesktop ?? false,
          );
          final grid = _grid;
          setState(() {
            widget.choices
              ..sort = 'none'
              ..save();
            _positions = {
              for (var i = 0; i < order.length; i++)
                order[i].name: grid.cell(grid.nth(i).$1, grid.nth(i).$2),
            };
          });
          _store();
        }
    }
    _announce();
  }

  void _open(List<Entry> items) {
    for (final e in items) {
      if (e.isDirectory) {
        openFolder(e.path);
      } else {
        _launch('xdg-open ${shellQuote(e.path)}');
      }
    }
  }

  /// A file manager window on `path` (another process, from the app's .desktop entry).
  void openFolder(String path) {
    final app = AppRegistry.load(
      env: widget.env,
      mime: systemMime,
    ).apps['dev.frascella.Mustache.desktop'];
    final args = app == null ? const <String>[] : execArguments(app, [path]);
    _launch(
      args.isEmpty
          ? 'xdg-open ${shellQuote(path)}'
          : args.map(shellQuote).join(' '),
    );
  }

  /// Headline on accent: Inter 13 / 18 semibold, white.
  static const TextStyle _labelStyle = TextStyle(
    fontFamily: uiFontFamily,
    package: 'silica_ui',
    fontSize: desktopLabelSize,
    height: desktopLabelLine / desktopLabelSize,
    fontWeight: FontWeight.w600,
    color: Color(0xFFFFFFFF),
  );

  /// The lines of an icon's name, by key (an item's key is its name, a stack's `stack:<kind>`).
  List<String> _linesOf(String key) => _lines.putIfAbsent(
    key,
    () => labelLines(
      key.startsWith('stack:') ? key.substring(6) : key,
      desktopLabelWidth,
      _labelStyle,
    ),
  );

  double _lineWidth(String line) => _lineWidths.putIfAbsent(line, () {
    final painter = TextPainter(
      text: TextSpan(text: line, style: _labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  });

  /// The icon's square (96 pt, its top at `at.dy`).
  static Rect _iconRect(Offset at) => Rect.fromLTWH(
    at.dx - desktopIconSide / 2,
    at.dy,
    desktopIconSide,
    desktopIconSide,
  );

  /// The rectangle of the name (the capsule when selected): one, hugging its lines.
  List<Rect> _labelRects(String key, Offset at) {
    final lines = _linesOf(key);
    final width = lines.fold<double>(
      0,
      (w, line) => math.max(w, _lineWidth(line)),
    );
    return [
      Rect.fromLTWH(
        at.dx - (width + 2 * desktopCapsulePad) / 2,
        at.dy + desktopIconSide + desktopLabelGap,
        width + 2 * desktopCapsulePad,
        desktopLabelLine * lines.length + 2 * desktopCapsulePadY,
      ),
    ];
  }

  /// The icon under a point: its selection square or one of the lines of its name.
  String? keyAt(Offset p) {
    for (final MapEntry(:key, :value) in _positions.entries.toList().reversed) {
      if (_iconRect(value).inflate(desktopSelectionPad).contains(p) ||
          _labelRects(key, value).any((r) => r.contains(p))) {
        return key;
      }
    }
    return null;
  }

  /// The icons the rubber band touches: by the icon or by its name (MU-30).
  Set<String> keysIn(Rect band) => {
    for (final MapEntry(:key, :value) in _positions.entries)
      if (_iconRect(value).overlaps(band) ||
          _labelRects(key, value).any((r) => r.overlaps(band)))
        key,
  };

  bool get _extend =>
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isShiftPressed;

  void _pointerDown(PointerDownEvent e) {
    _focus.requestFocus();
    // A drag Ossido never reported back on: over.
    if (_drag != null && !(_drag?.local ?? false)) _endDrag();
    _lastDrag = null;
    final key = keyAt(e.localPosition);
    if (e.buttons & kSecondaryButton != 0) {
      if (key != null && !_selected.contains(key)) {
        setState(() {
          _selected
            ..clear()
            ..add(key);
        });
      }
      if (key == null) setState(_selected.clear);
      _announce();
      _broadcast(
        'desktopmenu',
        '${e.position.dx} ${e.position.dy} ${key == null ? 'desktop' : 'items'}',
      );
      return;
    }
    if (e.buttons & kPrimaryButton == 0) return;
    if (_renaming != null) setState(() => _renaming = null);
    if (key == null) {
      setState(() {
        if (!_extend) _selected.clear();
        _bandBase = {..._selected};
        _bandStart = e.localPosition;
        _bandEnd = e.localPosition;
      });
      _announce();
      return;
    }
    final now = DateTime.now();
    final again =
        key == _lastClickKey && now.difference(_lastClick) < desktopDoubleClick;
    _lastClickKey = key;
    _lastClick = now;
    setState(() {
      if (_extend) {
        _selected.contains(key) ? _selected.remove(key) : _selected.add(key);
      } else if (!_selected.contains(key)) {
        _selected
          ..clear()
          ..add(key);
      }
    });
    _announce();
    if (again) {
      _lastClickKey = null;
      final stack = _icons().where((i) => i.key == key && i.stack != null);
      if (stack.isNotEmpty) {
        setState(() {
          _openStack = _openStack == key ? null : key;
          _relayout();
        });
      } else {
        _open(_selection);
      }
      return;
    }
    _pressKey = key;
    _pressAt = e.localPosition;
  }

  void _pointerMove(PointerMoveEvent e) {
    if (_bandStart case final start?) {
      setState(() {
        _bandEnd = e.localPosition;
        _selected
          ..clear()
          ..addAll(_bandBase)
          ..addAll(keysIn(Rect.fromPoints(start, e.localPosition)));
      });
      return;
    }
    final from = _pressAt;
    if (_pressKey == null || from == null) return;
    if (_dragging) {
      if (_drag case final drag? when drag.local) {
        setState(() => drag.pointer = e.localPosition);
      }
      return;
    }
    if ((e.localPosition - from).distance < desktopDragThreshold) return;
    _dragging = true;
    _beginDrag(from, e.localPosition);
  }

  /// The drag starts (MU-40): an image of the dragged icons and names, translucent, follows the
  /// pointer with a count badge for several items, while the icons stay in place, dimmed. The
  /// files go to Ossido's drag (other apps, Mustache windows, the Dock and its Trash, or back
  /// onto the desktop); outside Silica the image travels here.
  void _beginDrag(Offset from, Offset pointer) {
    final keys = {
      for (final k in _selected)
        if (_positions.containsKey(k)) k,
    };
    final paths = [for (final s in _selection) s.path];
    if (keys.isEmpty || paths.isEmpty) return;
    final (image, hotspot) = _dragImage(keys, from, paths.length);
    _drag?.image?.dispose();
    final drag = _DesktopDrag(
      keys: keys,
      paths: paths.toSet(),
      from: from,
      pointer: pointer,
      image: image,
      hotspot: hotspot,
    );
    setState(() => _drag = drag);
    startFileDrag(paths, image, hotspot).then((taken) {
      if (!taken && mounted && identical(_drag, drag)) {
        setState(() => drag.local = true);
      }
    });
  }

  /// The image of the dragged icons as they are on the desktop (icon and name in its capsule),
  /// at ~90 % (MU-40), with the count badge by `grab` (the press point); and the point of it
  /// that stays under the pointer: the press point, so the icons move with the pointer from where
  /// they were taken.
  (ui.Image?, Offset) _dragImage(Set<String> keys, Offset grab, int count) {
    final pieces = <(Offset, ui.Image)>[];
    try {
      for (final key in keys) {
        final boundary = _faces[key]?.currentContext?.findRenderObject();
        final at = _positions[key];
        if (boundary is! RenderRepaintBoundary || at == null) continue;
        if (!boundary.hasSize) continue;
        pieces.add((_faceOrigin(at), boundary.toImageSync()));
      }
      return composeDragImage(
        pieces,
        grab,
        count,
        badgeFromPointer: desktopBadgeFromPointer,
      );
    } on Object {
      // No image (a renderer that cannot read back): the drag goes on without one.
      return (null, Offset.zero);
    } finally {
      for (final (_, image) in pieces) {
        image.dispose();
      }
    }
  }

  /// The top left corner of what an icon paints (its face), from its position.
  static Offset _faceOrigin(Offset at) =>
      Offset(at.dx - desktopPitchX / 2, at.dy - desktopSelectionPad);

  void _pointerUp(PointerEvent e) {
    if (_bandStart != null) {
      setState(() => _bandStart = _bandEnd = null);
      _announce();
    }
    final drag = _drag;
    if (drag != null && drag.local && e is PointerUpEvent) {
      _dropOnDesktop(drag.keys, e.localPosition - drag.from);
    }
    // A cancel here is the embedder handing the drag to Ossido: the drag goes on there.
    if (drag != null && (drag.local || e is PointerUpEvent)) _endDrag();
    _pressKey = null;
    _pressAt = null;
    _dragging = false;
    if (mounted) setState(() {});
  }

  void _endDrag() {
    final drag = _drag;
    if (drag == null) return;
    _lastDrag = drag;
    final image = drag.image;
    if (mounted && drag.local && image != null && _free) {
      // The image (badge included) fades out where it was dropped.
      _fadeImage?.dispose();
      _fadeImage = image;
      _fadeAt = drag.pointer - drag.hotspot;
      _fade.forward(from: 0);
    } else {
      image?.dispose();
    }
    if (mounted) {
      setState(() => _drag = null);
    } else {
      _drag = null;
    }
  }

  void _dropFadeDone() {
    _fadeImage?.dispose();
    _fadeImage = null;
    if (mounted) setState(() {});
  }

  /// Dragged icons released on the desktop, `delta` from where they were. With free positions
  /// each one lands where its image was, in the same frame (R9.13); on an ordered desktop
  /// (sorted, stacks) they travel back to their cells (R15.7), as does any icon that would land
  /// off the screen.
  void _dropOnDesktop(Set<String> keys, Offset delta) {
    final released = {
      for (final k in keys)
        if (_positions[k] case final p?) k: p + delta,
    };
    if (released.isEmpty) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(released.keys);
    });
    if (_free) {
      _moveTo(released);
      // Free desktop: no snap, no fly. The normal selected look returns ~275 ms later.
      _unselectedYet.addAll(released.keys);
      _reselect?.cancel();
      _reselect = Timer(desktopDropSelect, () {
        _unselectedYet.clear();
        if (mounted) setState(() {});
      });
    }
    _settleFromAt({
      for (final MapEntry(:key, :value) in released.entries)
        if (_positions[key] case final p? when (p - value).distance > 0.5)
          key: value,
    });
    _announce();
  }

  /// Puts icons at `targets`, kept on the screen, and stores the positions.
  void _moveTo(Map<String, Offset> targets) {
    final next = {..._positions};
    for (final MapEntry(:key, :value) in targets.entries) {
      next[key] = Offset(
        value.dx.clamp(
          desktopIconSide / 2,
          math.max(desktopIconSide / 2, _size.width - desktopIconSide / 2),
        ),
        value.dy.clamp(0, math.max(0, _size.height - desktopIconSide)),
      );
    }
    setState(() => _positions = next);
    _store();
  }

  /// Icons drawn from `from` travelling to their positions.
  void _settleFromAt(Map<String, Offset> from) {
    if (from.isEmpty) return;
    _settleFrom = from;
    _settle.forward(from: 0);
  }

  /// Files dropped by another app or by the desktop itself.
  void _externalDrag(SilicaDragEvent event) {
    if (!mounted) return;
    if (event is SilicaDragFinished) {
      // The drag that left from here is over: dropped elsewhere (the files go there, the
      // folder watcher removes the icons), here (the drop moves them), or cancelled.
      _endDrag();
      return;
    }
    if (event is! SilicaDrop) return;
    final paths = event.paths;
    if (paths.isEmpty) return;
    final inside = paths.every((p) => File(p).parent.path == widget.folder);
    if (inside) {
      final names = paths.map(displayName).toSet();
      // Our own icons came back: they keep where the pointer grabbed them.
      final own = _drag ?? _lastDrag;
      if (own != null && own.paths.containsAll(paths)) {
        _dropOnDesktop(own.keys, event.position - own.from);
        _endDrag();
        _lastDrag = null;
        return;
      }
      // From a window showing the desktop folder: the first item lands at the drop, the
      // others keep their offsets.
      final first = displayName(paths.first);
      final anchor = _positions[first];
      if (anchor == null) return;
      final to = event.position - const Offset(0, desktopIconSide / 2);
      _dropOnDesktop({
        for (final n in names)
          if (_positions.containsKey(n)) n,
      }, to - anchor);
      return;
    }
    final moved = <String>[];
    // Copies across disks still running: the one sound comes when the last is done.
    final copies = <Future<bool>>[];
    for (final p in paths) {
      final name = uniqueName(widget.folder, displayName(p));
      final target = '${widget.folder}/$name';
      try {
        FileSystemEntity.typeSync(p) == FileSystemEntityType.directory
            ? Directory(p).renameSync(target)
            : File(p).renameSync(target);
        moved.add(name);
      } on FileSystemException {
        // Another disk: copied instead, as the windows do across disks.
        copies.add(
          Process.start('cp', ['-a', p, target])
              .then((process) => process.exitCode)
              .then((code) => code == 0)
              .catchError((_) => false),
        );
      }
    }
    // One sound per operation, when it is complete (FILE-SOUNDS): after the last copy, or at
    // once when everything was an instant move.
    final anyMoved = moved.isNotEmpty;
    Future.wait(copies).then((done) {
      if (anyMoved || done.contains(true)) {
        unawaited(playUiSound(UiSound.fileTransfer));
      }
    }).ignore();
    _load();
    if (_free && moved.isNotEmpty) {
      final grid = _grid;
      final taken = grid.taken(_positions.values);
      final next = {..._positions};
      for (final name in moved) {
        final at = grid.nearestFree(
          event.position - const Offset(0, desktopIconSide / 2),
          taken,
        );
        taken.add(grid.cellOf(at));
        next[name] = at;
      }
      setState(() => _positions = next);
      _store();
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_renaming != null) return KeyEventResult.ignored;
    final meta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.enter && _selected.length == 1) {
      runAction('rename');
    } else if (meta && k == LogicalKeyboardKey.keyO) {
      runAction('open');
    } else if (meta && k == LogicalKeyboardKey.backspace) {
      runAction('trash');
    } else if (meta && k == LogicalKeyboardKey.keyD) {
      runAction('duplicate');
    } else if (meta && shift && k == LogicalKeyboardKey.keyN) {
      runAction('newFolder');
    } else if (meta && k == LogicalKeyboardKey.keyA) {
      setState(() {
        _selected
          ..clear()
          ..addAll(_positions.keys);
      });
      _announce();
    } else if (k == LogicalKeyboardKey.escape) {
      setState(_selected.clear);
      _announce();
    } else if (_arrow(k) case final direction?) {
      final from = _selected.isEmpty ? null : _selected.last;
      final next = from == null
          ? _positions.keys.firstOrNull
          : spatialNeighbour(_positions, from, direction);
      if (next != null) {
        setState(() {
          _selected
            ..clear()
            ..add(next);
        });
        _announce();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static Offset? _arrow(LogicalKeyboardKey k) => switch (k) {
    LogicalKeyboardKey.arrowUp => const Offset(0, -1),
    LogicalKeyboardKey.arrowDown => const Offset(0, 1),
    LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
    LogicalKeyboardKey.arrowRight => const Offset(1, 0),
    _ => null,
  };

  /// Where an icon is drawn: its position, or on its way there after a drop.
  Offset _drawnAt(String key, Offset at) {
    final from = _settleFrom[key];
    if (from == null || !_settle.isAnimating) return at;
    return Offset.lerp(from, at, Curves.decelerate.transform(_settle.value)) ??
        at;
  }

  /// Publishes the desktop's menus at the end of this frame (the desktop focused: the bar shows
  /// these while no window is in front). The window actions are disabled; Sort By, Use Stacks and
  /// the file operations of the selected icons work.
  void _queueMenus() {
    if (_menuQueued) return;
    _menuQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _menuQueued = false;
      final hub = _menuHub;
      if (!mounted || hub == null) return;
      hub.publish(this, buildMenus(_menuSpec()));
    });
  }

  MenuSpec _menuSpec() {
    final items = _selection;
    final home = widget.env?['HOME'] ?? Platform.environment['HOME'];
    VoidCallback? act(String id, {bool when = true}) =>
        when && _renaming == null ? () => runAction(id) : null;
    String? place(PlaceKind kind) =>
        widget.places.where((p) => p.kind == kind).firstOrNull?.path;
    return MenuSpec(
      selectionName: items.length == 1 ? items.single.name : null,
      selectionCount: items.length,
      selectionIsFolder: items.length == 1 && items.single.isDirectory,
      editingText: _renaming != null,
      newWindow: home == null ? null : () => openFolder(home),
      newFolder: act('newFolder'),
      open: act('open', when: items.isNotEmpty),
      rename: act('rename', when: items.length == 1),
      duplicate: act('duplicate', when: items.isNotEmpty),
      moveToTrash: act('trash', when: items.isNotEmpty),
      selectAll: _positions.isEmpty || _renaming != null
          ? null
          : () {
              setState(() {
                _selected
                  ..clear()
                  ..addAll(_positions.keys);
              });
              _announce();
            },
      useStacks: true,
      stacksOn: widget.choices.stacks,
      toggleStacks: act('stacks'),
      sortChecked: widget.choices.sort,
      sortBy: (key) => runAction('sort:$key'),
      sortNone: act('sort:none'),
      goTo: openFolder,
      places: {
        for (final (goPlace, kind) in [
          (GoPlace.documents, PlaceKind.documents),
          (GoPlace.desktop, PlaceKind.desktop),
          (GoPlace.downloads, PlaceKind.downloads),
          (GoPlace.home, PlaceKind.home),
        ])
          if (place(kind) case final path?) goPlace: path,
        GoPlace.computer: '/',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _queueMenus();
    final size = MediaQuery.sizeOf(context);
    if (size != _size) {
      _size = size;
      _relayout();
    }
    final dark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    final band = _bandStart == null || _bandEnd == null
        ? null
        : Rect.fromPoints(_bandStart!, _bandEnd!);
    final icons = _icons();
    final byKey = {for (final i in icons) i.key: i};
    final members = {
      if (_openStack case final open?)
        for (final m in byKey[open]?.members ?? const <Entry>[])
          m.name: DesktopIcon.item(m),
    };
    final drag = _drag;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerUp,
        onPointerCancel: _pointerUp,
        child: SizedBox.expand(
          child: Stack(
            children: [
              for (final MapEntry(:key, :value) in _positions.entries)
                if (byKey[key] ?? members[key] case final icon?)
                  _iconAt(
                    icon,
                    _drawnAt(key, value),
                    dark: dark,
                    dimmed: drag?.keys.contains(key) ?? false,
                  ),
              if (band != null)
                Positioned.fromRect(
                  rect: band,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const ValueKey('desktop rubber band'),
                      decoration: BoxDecoration(
                        color: dark ? desktopBandFill : desktopBandFillLight,
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: dark
                                ? desktopBandBorder
                                : desktopBandBorderLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (drag != null && drag.local && drag.image != null)
                Positioned(
                  left: drag.pointer.dx - drag.hotspot.dx,
                  top: drag.pointer.dy - drag.hotspot.dy,
                  child: IgnorePointer(
                    child: RawImage(
                      key: const ValueKey('desktop drag image'),
                      image: drag.image,
                    ),
                  ),
                ),
              if (_fadeImage != null)
                Positioned(
                  left: _fadeAt.dx,
                  top: _fadeAt.dy,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 1 - _fade.value,
                      child: RawImage(
                        key: const ValueKey('desktop drop fade'),
                        image: _fadeImage,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconAt(
    DesktopIcon icon,
    Offset at, {
    required bool dark,
    required bool dimmed,
  }) {
    final isSelected = _selected.contains(icon.key);
    final shown = isSelected && !_unselectedYet.contains(icon.key);
    final shadowed = _labelStyle.copyWith(
      shadows: const [
        Shadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 3),
      ],
    );
    final lines = labelLines(icon.label, desktopLabelWidth, _labelStyle);
    final renaming = icon.entry != null && icon.entry?.name == _renaming;
    final face = Column(
      children: [
        const SizedBox(height: desktopSelectionPad),
        SizedBox.square(
          dimension: desktopIconSide,
          child: icon.entry != null
              ? EntryIcon(
                  entry: icon.entry!,
                  side: desktopIconSide,
                  env: widget.env,
                )
              : _StackIcon(members: icon.members, env: widget.env),
        ),
        const SizedBox(height: desktopLabelGap),
        if (renaming)
          RenameField(
            name: icon.entry!.name,
            isDirectory: icon.entry!.isDirectory,
            maxWidth: desktopPitchX,
            onCommit: (name) {
              renameEntry(icon.entry!.path, name);
              setState(() => _renaming = null);
              _load();
            },
            onCancel: () => setState(() => _renaming = null),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: desktopCapsulePad,
              vertical: desktopCapsulePadY,
            ),
            decoration: shown
                ? BoxDecoration(
                    color: !_surfaceActive
                        ? desktopCapsuleInactive
                        : AmalfiTheme.of(context).colors.accentAmalfi,
                    borderRadius: BorderRadius.circular(desktopCapsuleRadius),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in lines)
                  SizedBox(
                    height: desktopLabelLine,
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        line,
                        maxLines: 1,
                        softWrap: false,
                        style: !shown
                            ? shadowed
                            : _surfaceActive
                            ? _labelStyle
                            : _labelStyle.copyWith(
                                color: desktopCapsuleInactiveText,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    final height =
        desktopSelectionPad +
        desktopIconSide +
        desktopLabelGap +
        desktopLabelLine * math.max(lines.length, 2) +
        2 * desktopCapsulePadY +
        4;
    return Positioned(
      key: ValueKey('desktop ${icon.key}'),
      left: at.dx - desktopPitchX / 2,
      top: at.dy - desktopSelectionPad,
      width: desktopPitchX,
      height: height,
      child: Opacity(
        opacity: dimmed ? desktopDragDim : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Behind the icon, outside the layout: it never moves the icon or the name.
            if (shown)
              const Positioned(
                left: (desktopPitchX - desktopSelectionSide) / 2,
                top: 0,
                width: desktopSelectionSide,
                height: desktopSelectionSide,
                child: _SelectionSquare(),
              ),
            Positioned.fill(
              child: RepaintBoundary(
                key: _faces.putIfAbsent(icon.key, GlobalKey.new),
                child: face,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The square behind a selected icon: the outline in the outer 2 pt, the dark fill inside it.
class _SelectionSquare extends StatelessWidget {
  const _SelectionSquare();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    key: ValueKey('desktop selection'),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(desktopSelectionRadius)),
      border: Border.fromBorderSide(
        BorderSide(
          color: desktopSelectionOutline,
          width: desktopSelectionOutlineWidth,
        ),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(desktopSelectionOutlineWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: desktopSelectionFill,
          borderRadius: BorderRadius.all(
            Radius.circular(
              desktopSelectionRadius - desktopSelectionOutlineWidth,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A closed stack: 2–3 of its items' icons overlapping, slightly rotated, no count (R15.2).
class _StackIcon extends StatelessWidget {
  const _StackIcon({required this.members, this.env});

  final List<Entry> members;
  final Map<String, String>? env;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    const angles = [-0.08, 0.06, 0.0];
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = shown.length - 1; i >= 0; i--)
          Transform.rotate(
            angle: angles[i % angles.length],
            child: EntryIcon(
              entry: shown[i],
              side: desktopIconSide * 0.86,
              env: env,
            ),
          ),
      ],
    );
  }
}
