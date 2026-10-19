// Dragging items out of the view (MU-40) and the slow click that renames (R8).
//
// Items are pressed through raw pointer events, not gestures: a drag never waits on the gesture
// arena, so the rubber band, the taps and the double click cannot take it away. Past the view's
// threshold the drag starts: the dragged items stay in place, dimmed, and the image of them is
// handed to Ossido (`silica/drag` › `start`, grabbed at the press point) right away, so the files
// reach any window, the desktop, the Dock and other apps. Over this window Ossido's drag comes
// back as `enter`/`motion`/`drop`: the folder under the pointer lights up, springs open after
// hovering and receives the drop. Outside Silica the image travels inside the window.

part of 'window.dart';

/// A press on an item of the view.
class _ItemPress {
  _ItemPress({
    required this.entry,
    required this.pointer,
    required this.at,
    required this.local,
    required this.threshold,
    required this.anchor,
    required this.faces,
    required this.slowClick,
  });

  final Entry entry;
  final int pointer;

  /// The press point, global and in the item.
  final Offset at;
  final Offset local;

  /// The movement that starts the drag.
  final double threshold;

  /// The top left corner of the item's icon, in the item: the drag image's pill is held there.
  final Offset anchor;

  /// The image is the items as drawn (icons, thumbnails) instead of the pills.
  final bool faces;

  /// Released without moving it renames (a press on the name of the only selected item, no
  /// modifiers, not the second click of a double click).
  final bool slowClick;
  bool dragged = false;
}

/// A drag that left from this window.
class _WindowDrag {
  _WindowDrag({
    required this.payload,
    required this.pointer,
    required this.hotspot,
  });

  final DragPayload payload;

  /// Where the pointer is (global) and the point of the image under it.
  Offset pointer;
  Offset hotspot;

  /// The image as drawn by the window (icons): shown here and handed to Ossido.
  ui.Image? faces;

  /// The picture of the pills handed to Ossido.
  ui.Image? picture;

  /// Ossido took the drag: the image is its own, and the drop comes back as `drop`.
  bool handedOver = false;

  /// Ossido did not take it (outside Silica): the drag stays in the window.
  bool local = false;

  /// The press was released here before Ossido answered: the drop happened here.
  bool released = false;
}

extension _Drag on _MustacheWindowState {
  /// The items that leave when dragging `entry`: the selection if it belongs to it, otherwise the
  /// entry alone.
  List<String> _dragPaths(Entry entry) => _selected.contains(entry.path)
      ? [for (final e in _selection) e.path]
      : [entry.path];

  /// The paths being dragged (dimmed in place).
  bool _isDragged(String path) => _drag?.payload.paths.contains(path) ?? false;

  /// An item of a view: pressing it may start a drag past `threshold` (list and columns 1 pt,
  /// icons ~8 pt, R7.3) or, released, a slow click. `anchor` is where the item's icon starts (the
  /// pills of the image are held there); with `faces` the image is the item as drawn.
  Widget _itemPress(
    Entry entry,
    Widget child, {
    required double threshold,
    Offset anchor = Offset.zero,
    bool faces = false,
  }) {
    final dimmed = faces && _isDragged(entry.path);
    return Listener(
      onPointerDown: (e) => _itemDown(
        e,
        entry,
        threshold: threshold,
        anchor: anchor,
        faces: faces,
      ),
      child: Opacity(
        opacity: dimmed ? dragDim : 1,
        child: faces
            ? RepaintBoundary(
                key: _faces.putIfAbsent(entry.path, GlobalKey.new),
                child: child,
              )
            : child,
      ),
    );
  }

  /// A press on an item's name (heard before the item's press): it may be a slow click if the
  /// item is already the only one selected.
  void _namePress(Entry entry) {
    _nameDown = (
      entry.path,
      _selected.length == 1 && _selected.contains(entry.path),
    );
  }

  void _itemDown(
    PointerDownEvent e,
    Entry entry, {
    required double threshold,
    required Offset anchor,
    required bool faces,
  }) {
    _endStaleDrag();
    _slowClick?.cancel();
    final name = _nameDown;
    _nameDown = null;
    if (e.buttons & kPrimaryButton == 0) {
      _press = null;
      return;
    }
    final keys = HardwareKeyboard.instance;
    final plain =
        !keys.isMetaPressed &&
        !keys.isControlPressed &&
        !keys.isShiftPressed &&
        !keys.isAltPressed;
    // The second press of a double click never renames.
    final quick = _recentClick == entry.path;
    _press = _ItemPress(
      entry: entry,
      pointer: e.pointer,
      at: e.position,
      local: e.localPosition,
      threshold: threshold,
      anchor: anchor,
      faces: faces,
      slowClick:
          plain && !quick && name != null && name.$1 == entry.path && name.$2,
    );
    _pressAt = e.position;
  }

  /// Every press in the window, after the item's own: one on nothing ends the slow-click wait.
  void _windowDown(PointerDownEvent e) {
    _lastDrag = null;
    if (_press?.pointer == e.pointer) return;
    _nameDown = null;
    _press = null;
    _slowClick?.cancel();
    _endStaleDrag();
  }

  void _windowMove(PointerMoveEvent e) {
    final press = _press;
    if (press == null || press.pointer != e.pointer) return;
    final drag = _drag;
    if (press.dragged) {
      if (drag == null || drag.handedOver) return;
      _update(() => drag.pointer = e.position);
      _hoverAt(e.position, drag.payload);
      return;
    }
    if ((e.position - press.at).distance <= press.threshold) return;
    press.dragged = true;
    _beginDrag(press, e.position);
  }

  void _windowUp(PointerUpEvent e) {
    final press = _press;
    if (press == null || press.pointer != e.pointer) return;
    _press = null;
    final drag = _drag;
    if (!press.dragged) {
      _clickUp(press);
      return;
    }
    if (drag == null || drag.handedOver) return;
    // Released here (outside Silica, or before Ossido answered): the drop is here.
    drag.released = true;
    _dropAt(e.position, drag.payload, own: true);
    _endDrag();
  }

  void _windowCancel(PointerCancelEvent e) {
    final press = _press;
    if (press == null || press.pointer != e.pointer) return;
    _press = null;
    // A cancel during a drag is the embedder handing it to Ossido: it goes on there, and ends
    // with `finished`.
    final drag = _drag;
    if (drag != null && drag.local) _endDrag();
  }

  /// A click released without a drag: on the name of the item that was already the only one
  /// selected, the field opens after ~440 ms unless a second click comes first (R8, MU-32). A
  /// click on the icon, a drag, a rubber band or a double click never rename.
  void _clickUp(_ItemPress press) {
    final path = press.entry.path;
    if (_collapseTo == path) {
      _update(() {
        _selected
          ..clear()
          ..add(path);
      });
    }
    _collapseTo = null;
    _recentClick = path;
    _recentClickTimer?.cancel();
    _recentClickTimer = Timer(kDoubleTapTimeout, () => _recentClick = null);
    _slowClick?.cancel();
    if (!press.slowClick) return;
    _slowClick = Timer(slowClickRename, () {
      if (mounted && _selected.length == 1 && _selected.contains(path)) {
        _startRename(path);
      }
    });
  }

  /// The drag starts: the items stay in place, dimmed; the image is handed to Ossido.
  void _beginDrag(_ItemPress press, Offset pointer) {
    _slowClick?.cancel();
    _collapseTo = null;
    _rowDragged = true;
    final paths = _dragPaths(press.entry);
    if (paths.isEmpty) return;
    final payload = DragPayload(
      paths,
      parentOf(paths.first) ?? _history.current,
    );
    _endDrag();
    final drag = _WindowDrag(
      payload: payload,
      pointer: pointer,
      hotspot: Offset.zero,
    );
    if (press.faces) {
      final (image, hotspot) = _facesImage(paths, press.at);
      drag
        ..faces = image
        ..hotspot = hotspot;
    }
    if (drag.faces == null) drag.hotspot = _pillsHotspot(press, paths);
    _update(() => _drag = drag);
    _hoverAt(pointer, payload);
    if (drag.faces case final image?) {
      _handOver(drag, image);
      return;
    }
    // The pills are laid out by Flutter: their picture is ready after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_drag, drag) || drag.released) return;
      final boundary = _dragImageKey.currentContext?.findRenderObject();
      ui.Image? picture;
      try {
        if (boundary is RenderRepaintBoundary && boundary.hasSize) {
          picture = boundary.toImageSync();
        }
      } on Object {
        // A renderer that cannot read back: the drag goes on without an image.
      }
      drag.picture = picture;
      _handOver(drag, picture);
    });
  }

  void _handOver(_WindowDrag drag, ui.Image? image) {
    startFileDrag(drag.payload.paths, image, drag.hotspot).then((taken) {
      if (!mounted || !identical(_drag, drag) || drag.released) return;
      _update(() {
        drag.handedOver = taken;
        drag.local = !taken;
      });
    });
  }

  /// The image of the dragged items as drawn in the view (icon and name, thumbnail), with the
  /// count badge by the press point, which stays under the pointer.
  (ui.Image?, Offset) _facesImage(List<String> paths, Offset grab) {
    final pieces = <(Offset, ui.Image)>[];
    try {
      for (final path in paths) {
        final boundary = _faces[path]?.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary || !boundary.hasSize) continue;
        if (!boundary.attached) continue;
        pieces.add((
          boundary.localToGlobal(Offset.zero),
          boundary.toImageSync(),
        ));
      }
      if (pieces.isEmpty) return (null, Offset.zero);
      return composeDragImage(pieces, grab, paths.length);
    } on Object {
      return (null, Offset.zero);
    } finally {
      for (final (_, image) in pieces) {
        image.dispose();
      }
    }
  }

  /// The point of the pills under the pointer: where the press was on the grabbed item, from its
  /// icon (the pill's icon), kept inside the image.
  Offset _pillsHotspot(_ItemPress press, List<String> paths) {
    final shown = paths.take(dragImageRows).toList();
    final row = math.max(0, shown.indexOf(press.entry.path));
    final name = TextPainter(
      text: TextSpan(
        text: displayName(press.entry.path),
        style: const TextStyle(
          fontFamily: uiFontFamily,
          package: 'silica_ui',
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = dragImagePad + 16 + 4 + 10 + name.width;
    name.dispose();
    final height = dragImagePad + dragRowPitch * shown.length;
    final at =
        const Offset(dragImagePad, dragImagePad) +
        Offset(0, dragRowPitch * row) +
        (press.local - press.anchor);
    return Offset(
      at.dx.clamp(0, math.max(0, width - 1)),
      at.dy.clamp(0, math.max(0, height - 1)),
    );
  }

  /// The drag that left from here is over (dropped, cancelled, or never reported back).
  void _endDrag() {
    final drag = _drag;
    if (drag == null) return;
    _lastDrag = drag;
    _drag = null;
    _dropHover.value = null;
    _cancelSpring();
    if (mounted) _update(() {});
    // The image may still be on screen in this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      drag.faces?.dispose();
      drag.picture?.dispose();
    });
  }

  /// A drag Ossido never reported back on (no `finished`): over at the next press.
  void _endStaleDrag() {
    if (_drag?.handedOver ?? false) _endDrag();
  }

  /// The folder under a drag at `position` lights up; after hovering it springs open (R9.1).
  void _hoverAt(Offset position, DragPayload? payload) {
    if (!mounted) return;
    final meta = folderAt(position, View.of(context).viewId);
    var path = meta?.path;
    if (path != null && payload != null && !canDrop(payload, path)) {
      path = null;
    }
    if (path == _dropHover.value) return;
    _dropHover.value = path;
    _cancelSpring();
    final spring = meta?.onSpring;
    if (path == null || spring == null) return;
    _armSpring(spring);
  }

  /// Stops the wait of a spring-loaded folder, and its blink.
  void _cancelSpring() {
    for (final timer in _spring) {
      timer.cancel();
    }
    _spring.clear();
    _springAction = null;
    _dropBlink.value = false;
  }

  /// Starts the wait: the folder blinks at ~340 ms (highlight off 80 ms, on 107 ms, off) and
  /// opens at ~715 ms (MU-40).
  void _armSpring(VoidCallback spring) {
    _cancelSpring();
    _springAction = spring;
    void at(Duration after, void Function() action) => _spring.add(
      Timer(after, () {
        if (mounted) action();
      }),
    );
    at(springBlinkAt, () => _dropBlink.value = true);
    at(springBlinkAt + springBlinkOff, () => _dropBlink.value = false);
    at(springBlinkAt + springBlinkOff + springBlinkOn, () {
      _dropBlink.value = true;
    });
    at(springOpen, () {
      _dropHover.value = null;
      _cancelSpring();
      spring();
    });
  }

  /// A modifier pressed or released during the wait restarts the count (MU-40).
  bool _springKey(KeyEvent event) {
    final spring = _springAction;
    if (spring != null && event is! KeyRepeatEvent && _isModifier(event)) {
      _armSpring(spring);
    }
    return false;
  }

  static bool _isModifier(KeyEvent event) {
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  /// Ossido's drags over this window: from here, from another window, from another app.
  void _dragEvent(SilicaDragEvent event) {
    if (!mounted) return;
    switch (event) {
      case SilicaDragOver(:final position):
        if (widget.focused) _hoverAt(position, _drag?.payload);
      case SilicaDragLeave():
        _dropHover.value = null;
        _cancelSpring();
      case final SilicaDrop drop:
        _externalDrop(drop);
      case SilicaDragFinished():
        // The drag that left from here is over: dropped (here the drop moved or copied the
        // files, elsewhere the other side did) or cancelled.
        if (_drag?.handedOver ?? false) _endDrag();
    }
  }

  /// Files dropped through Ossido: this window's own drag coming back, another window's, another
  /// app's. Onto the folder under the pointer, otherwise into the open one.
  void _externalDrop(SilicaDrop drop) {
    _dropHover.value = null;
    _cancelSpring();
    final paths = drop.paths;
    if (paths.isEmpty || !widget.focused) return;
    final own = _drag ?? _lastDrag;
    if (own != null &&
        own.payload.paths.length == paths.length &&
        own.payload.paths.toSet().containsAll(paths)) {
      _lastDrag = null;
      // Released here before Ossido answered: already dropped.
      if (!own.released) _dropAt(drop.position, own.payload, own: true);
      return;
    }
    final from = File(paths.first).parent.path;
    _dropAt(drop.position, DragPayload(paths, from), own: false);
  }

  /// The drop at `position`: icons of this folder dropped in its own view with free positions
  /// move (R4.7); otherwise into the folder under the pointer (the open one for files from
  /// elsewhere); released on nothing (the toolbar) nothing moves (R9.3).
  void _dropAt(Offset position, DragPayload payload, {required bool own}) {
    _dropHover.value = null;
    _cancelSpring();
    final meta = folderAt(position, View.of(context).viewId);
    final inPlace =
        meta != null &&
        (meta.path == _history.current || !canDrop(payload, meta.path));
    if (own &&
        inPlace &&
        _view == ViewMode.icons &&
        !_searching &&
        _acceptsMove(payload)) {
      _moveDropped(payload, position);
      return;
    }
    final destination = meta?.path ?? (own ? null : _history.current);
    if (destination == null || !canDrop(payload, destination)) return;
    if (payload.paths.every((p) => parentOf(p) == destination)) return;
    (meta?.onDrop ?? _drop)(payload, destination);
  }

  /// A folder of the view as a drop target (and spring-loaded folder: it opens after hovering).
  Widget _folderTarget(
    Entry entry,
    Widget Function(BuildContext context, bool active) builder,
  ) => entry.isDirectory
      ? FolderDropTarget(
          path: entry.path,
          onDrop: _drop,
          onSpring: () {
            if (mounted) _navigate(entry.path);
          },
          builder: builder,
        )
      : builder(context, false);

  /// A folder of the icon view, the columns or the gallery lit as a destination.
  Widget _litFolder(Entry entry, Widget child, {double radius = 6}) =>
      _folderTarget(
        entry,
        (context, active) => active
            ? Container(
                foregroundDecoration: BoxDecoration(
                  color: AmalfiTheme.of(context).colors.accentAmalfiSoft,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: child,
              )
            : child,
      );

  /// Drop: move or copy (R9.1) into the destination.
  void _drop(DragPayload payload, String destination) {
    // Apps dropped on Applications (or on its alias in a disk image) are installed.
    if (_isInstall(payload.paths, destination)) {
      unawaited(_installApps(payload.paths));
      return;
    }
    final copy = dropCopies(payload.paths, destination);
    _startTransfer(
      copy ? TransferKind.copy : TransferKind.move,
      payload.paths,
      destination,
    );
  }

  /// The image of a drag travelling inside the window (until Ossido takes it, or outside Silica).
  Widget? _dragLayer() {
    final drag = _drag;
    if (drag == null || drag.handedOver) return null;
    final at = drag.pointer - drag.hotspot;
    return Positioned(
      left: at.dx,
      top: at.dy,
      child: IgnorePointer(
        key: const ValueKey('drag image'),
        child: switch (drag.faces) {
          final image? => RawImage(image: image),
          null => RepaintBoundary(
            key: _dragImageKey,
            child: DragImage(paths: drag.payload.paths, env: widget.iconsEnv),
          ),
        },
      ),
    );
  }
}

/// Keeps an `Overlay` above the window (dragged images live there) and rebuilds its entry when the
/// window changes.
class _OverlayHost extends StatefulWidget {
  const _OverlayHost({required this.child});
  final Widget child;

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_OverlayHost old) {
    super.didUpdateWidget(old);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
