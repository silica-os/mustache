// The window's menus in the menu bar (menus.dart): what the state of this window lets each item
// do. The window publishes them after a frame when what the bar shows changed (menu_scope.dart);
// the actions read the state when they run, so a published action is never stale.

part of 'window.dart';

extension _WindowMenus on _MustacheWindowState {
  /// Publishes the menus at the end of this frame, if this tab is the one in front.
  void _queueMenus() {
    if (_menuQueued || !widget.focused) return;
    _menuQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _menuQueued = false;
      final hub = _menuHub;
      if (!mounted || hub == null || !widget.focused) return;
      hub.publish(this, buildMenus(_menuSpec()));
    });
  }

  /// Something the menus show changed outside a build (the clipboard, the focus).
  void _menusChanged() {
    if (!mounted) return;
    _queueMenus();
    WidgetsBinding.instance.scheduleFrame();
  }

  /// A tab command of the tabs host above this window, if there is one.
  bool get _hasTabs => Actions.maybeFind<NewTabIntent>(context) != null;

  void _tabCommand(Intent intent) => Actions.maybeInvoke(context, intent);

  MenuSpec _menuSpec() {
    final dialog = widget.dialog != null;
    final blocked = _modalOpen || _conflict != null;
    final items = _selection;
    final single = items.length == 1 ? items.first : null;
    final files = [
      for (final e in items)
        if (!e.isDirectory) e,
    ];
    final icons = _view == ViewMode.icons;
    VoidCallback? run(VoidCallback action, {bool when = true}) =>
        blocked || !when ? null : action;
    final tabs = _hasTabs;
    final parent = _tagView == null ? parentOf(_history.current) : null;
    String? place(PlaceKind kind) =>
        widget.places.where((p) => p.kind == kind).firstOrNull?.path;
    final sidebarShown = _sidebarOpen;
    return MenuSpec(
      selectionName: single?.name,
      selectionCount: items.length,
      selectionIsFolder: single?.isDirectory ?? false,
      inTrash: _trash.contains(_history.current),
      editingText:
          _renaming != null || _searchFocus.hasFocus || _saveFocus.hasFocus,
      newWindow: run(_newWindow, when: !dialog),
      newFolder: run(_newFolder),
      newTab: run(
        () => _tabCommand(const NewTabIntent()),
        when: tabs && !dialog,
      ),
      open: run(_openAll, when: items.isNotEmpty),
      openWith:
          !dialog &&
              !blocked &&
              files.isNotEmpty &&
              files.length == items.length
          ? _openWithItems(files)
          : const [],
      closeWindow: dialog
          ? () => _finish(const [])
          : tabs
          ? () => _tabCommand(const CloseTabIntent())
          : null,
      getInfo: run(_getInfo, when: !dialog),
      rename: run(_renameSelection, when: single != null && !dialog),
      duplicate: run(_duplicate, when: items.isNotEmpty && !dialog),
      quickLook: run(_toggleQuickPreview, when: items.isNotEmpty),
      moveToTrash: run(_moveToTrash, when: items.isNotEmpty && !dialog),
      emptyTrash: run(_confirmEmptyTrash, when: !dialog),
      undo: run(_undoLast, when: _undo.undoLabel != null && !dialog),
      undoLabel: _undo.undoLabel,
      redo: run(_redoLast, when: _undo.redoLabel != null && !dialog),
      redoLabel: _undo.redoLabel,
      copy: run(_copySelection, when: items.isNotEmpty && !dialog),
      cut: run(_cutSelection, when: items.isNotEmpty && !dialog),
      makeLink: run(_makeLink, when: items.isNotEmpty && !dialog),
      showOriginal: run(
        _showOriginal,
        when: single != null && single.isLink && !dialog,
      ),
      paste: run(
        () => _paste(move: FileClipboard.cut),
        when: FileClipboard.paths.isNotEmpty && !dialog,
      ),
      pasteCount: FileClipboard.paths.length,
      selectAll: run(_selectAll, when: _ordered.isNotEmpty),
      find: run(_startSearch),
      goToFolder: run(_openGoToFolder, when: !dialog),
      settings: dialog ? null : _openSettings,
      view: _view,
      setView: blocked ? null : _setView,
      galleryEnabled: !dialog,
      sortChecked: icons && _arrangement.free ? 'none' : _sort.name,
      sortBy: blocked ? null : (key) => _sortBy(SortKey.values.byName(key)),
      sortNone: run(_sortNone, when: icons),
      snapToGrid: run(_toggleSnap, when: icons),
      snapChecked: _arrangement.snap,
      cleanUp: run(() => _cleanUp(), when: icons && _arrangement.free),
      cleanUpBy: blocked || !icons
          ? null
          : (key) => _arrangeBy(SortKey.values.byName(key)),
      sidebarShown: sidebarShown,
      toggleSidebar: run(_toggleSidebar),
      previewShown: _previewPane || _previewForced,
      togglePreview: run(
        () => _togglePart(WindowPart.previewPane),
        when: !dialog && !_previewForced,
      ),
      pathBarShown: _pathBar,
      togglePathBar: run(_togglePathBar),
      statusBarShown: _statusBar,
      toggleStatusBar: run(
        () => _togglePart(WindowPart.statusBar),
        when: !dialog,
      ),
      back: run(_goBack, when: _history.canGoBack || _searching),
      forward: run(_goForward, when: _history.canGoForward),
      enclosing: run(_goParent, when: parent != null),
      goTo: blocked ? null : _navigate,
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
      previousTab: run(
        () => _tabCommand(const NextTabIntent(-1)),
        when: widget.tabBar != null,
      ),
      nextTab: run(
        () => _tabCommand(const NextTabIntent(1)),
        when: widget.tabBar != null,
      ),
    );
  }

  /// Open With › for the selected files: the app that opens their type by default on top, then
  /// the others by name (as in the context menu). The files are read when an item runs.
  List<PlatformMenuItem> _openWithItems(List<Entry> files) {
    final type = _typeOf(files.first);
    final preferred = _registry.defaultFor(type);
    final others = [
      for (final app in _registry.appsFor(type))
        if (app.id != preferred?.id) app,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    SilicaMenuItem item(String label, DesktopApp app) => SilicaMenuItem(
      label: label,
      icon: app.silicaIcon,
      onSelected: () => _openWith([
        for (final e in _selection)
          if (!e.isDirectory) e,
      ], app),
    );
    return [
      if (preferred != null)
        PlatformMenuItemGroup(
          members: [item(l10n.defaultApp(preferred.name), preferred)],
        ),
      if (others.isNotEmpty)
        PlatformMenuItemGroup(
          members: [for (final app in others) item(app.name, app)],
        ),
      PlatformMenuItemGroup(members: [SilicaMenuItem(label: l10n.otherApp)]),
    ];
  }

  /// File › Open: the selected files with their apps, or the folder.
  void _openAll() {
    final items = _selection;
    if (items.length == 1) {
      _openEntry(items.first);
    } else {
      _openWith([
        for (final e in items)
          if (!e.isDirectory) e,
      ]);
    }
  }

  void _renameSelection() {
    final only = _selection;
    if (only.length == 1) _startRename(only.first.path);
  }

  /// Edit › Select All: every item shown.
  void _selectAll() {
    _update(() => _select([for (final e in _ordered) e.path]));
    _focus.requestFocus();
  }

  /// The selection, or the open folder if there is none.
  void _getInfo() => _openInfo(
    _selected.isEmpty
        ? [_history.current]
        : [for (final e in _selection) e.path],
  );

  void _toggleQuickPreview() {
    if (_renaming != null || _modalOpen) return;
    _update(() => _quickPreview = !_quickPreview && _selected.isNotEmpty);
  }

  void _togglePathBar() {
    _update(() => _pathBar = !_pathBar);
    widget.settings?.pathBar = _pathBar;
  }

  void _togglePart(WindowPart part) {
    _update(() {
      switch (part) {
        case WindowPart.statusBar:
          _statusBar = !_statusBar;
          if (_statusBar) _free = freeBytes(_history.current);
          widget.settings?.statusBar = _statusBar;
        case WindowPart.previewPane:
          _previewPane = !_previewPane;
          widget.settings?.previewPane = _previewPane;
      }
    });
  }

  void _goParent() {
    final parent = parentOf(_history.current);
    if (parent != null) _navigate(parent);
  }

  void _goBack() {
    // From search, Back returns to the folder (R13.4).
    if (_searching) {
      _endSearch();
    } else if (_history.back()) {
      _load();
    }
  }

  void _goForward() {
    if (_history.forward()) _load();
  }
}
