// Context menus (MU-50, docs/spec/menus-and-settings.md) and opening with apps (R10.1): Open, Open With (the
// default on top, then the others by name), Move to Trash, Rename, Duplicate; on the background New
// Folder, View and Sort By. Entries for features not done yet stay visible and disabled, for the
// structure.

part of 'window.dart';

/// The menu opens with its top-left corner at the pointer (+1, −6) (spec/menus-and-settings.md).
const Offset contextMenuOffset = Offset(1, -6);

extension _Context on _MustacheWindowState {
  AppRegistry get _registry =>
      _apps ??= AppRegistry.load(env: widget.iconsEnv, mime: systemMime);

  /// The MIME type of an item, computed once per path and date.
  String _typeOf(Entry entry) {
    if (entry.isDirectory) return 'inode/directory';
    final key = '${entry.path}\u0000${entry.modified.microsecondsSinceEpoch}';
    return _types[key] ??= systemMime.typeOf(entry.path);
  }

  /// The Kind column: the name of the type's family (R3.3).
  String _kind(Entry entry) => kindLabel(entry, _typeOf(entry));

  /// Opens files with an app (or the default one of the first), with an alert when it cannot.
  Future<void> _openWith(List<Entry> files, [DesktopApp? app]) async {
    if (files.isEmpty) return;
    final custom = widget.open;
    if (custom != null && app == null) {
      for (final f in files) {
        custom(f.path);
      }
      return;
    }
    final chosen = app ?? _registry.defaultFor(_typeOf(files.first));
    if (chosen == null) {
      // No app declares the type: the system decides the rest.
      for (final f in files) {
        _MustacheWindowState._xdgOpen(f.path);
      }
      return;
    }
    final error = await launchApp(chosen, [for (final f in files) f.path]);
    if (error != null && mounted) _showError(error);
  }

  void _openContextMenu(Entry? entry, Offset position) {
    _slowClick?.cancel();
    // In the list a right click on an unselected row does not change the selection: the row gets
    // the ring and the menu applies to it alone (R3.9).
    final ring =
        entry != null &&
        !_selected.contains(entry.path) &&
        _view == ViewMode.list;
    if (entry != null && !_selected.contains(entry.path) && !ring) {
      _update(() => _select([entry.path]));
    }
    final items = entry == null
        ? const <Entry>[]
        : ring
        ? [entry]
        : _selection;
    _update(() => _contextRing = ring ? entry.path : null);
    _showMenu(
      position + contextMenuOffset,
      items.isEmpty ? _backgroundMenu() : _itemsMenu(items),
    );
  }

  /// Shows a menu above the window with its top-left corner at the global `position`; when it
  /// closes the ring goes and the keyboard goes back to the window.
  void _showMenu(Offset position, List<AmalfiMenuEntry> entries) {
    final host = _bodyKey.currentContext;
    if (host == null) return;
    showAmalfiMenu(
      context: host,
      position: position,
      entries: entries,
      opaque: true,
    ).whenComplete(() {
      if (!mounted) return;
      _update(() => _contextRing = null);
      // The popover that the menu item opened keeps the keyboard (Esc).
      (_customizing == null ? _focus : _customizeFocus).requestFocus();
    });
  }

  List<AmalfiMenuEntry> _itemsMenu(List<Entry> items) {
    final inTrash = _trash.contains(_history.current);
    final files = [
      for (final e in items)
        if (!e.isDirectory) e,
    ];
    final single = items.length == 1 ? items.first : null;
    return [
      if (items.length > 1)
        AmalfiMenuAction(
          l10n.newFolderWithSelection(items.length),
          enabled: false,
        ),
      AmalfiMenuAction(
        l10n.open,
        onSelected: () {
          if (single != null && single.isDirectory) {
            _openEntry(single);
          } else {
            _openWith(files);
          }
        },
      ),
      if (files.length == items.length) _openWithMenu(files),
      const AmalfiMenuDivider(),
      AmalfiMenuAction(
        inTrash ? l10n.restore : l10n.moveToTrash,
        onSelected: () => _moveToTrash(items),
      ),
      const AmalfiMenuDivider(),
      AmalfiMenuAction(
        l10n.showInfo,
        onSelected: () => _openInfo([for (final e in items) e.path]),
      ),
      AmalfiMenuAction(
        items.length > 1 ? l10n.renameMany : l10n.rename,
        enabled: single != null,
        onSelected: single == null ? null : () => _startRename(single.path),
      ),
      AmalfiMenuAction(l10n.duplicate, onSelected: () => _duplicate(items)),
      AmalfiMenuAction(l10n.copy, onSelected: () => _copySelection(items)),
      const AmalfiMenuDivider(),
      _tagMenu(items),
      if (single != null && single.isDirectory)
        AmalfiMenuAction(
          l10n.customizeFolder,
          onSelected: () => _customizeFolder(single.path),
        ),
    ];
  }

  /// Customize Folder…: the popover on the folder icon.
  void _customizeFolder(String path) {
    _update(() => _customizing = path);
  }

  /// "Edit Tags…" of the popover: closes it, selects the folder and shows the preview pane, where
  /// tags are typed.
  void _editTags(String path) => _update(() {
    _customizing = null;
    if (_entries.any((e) => e.path == path)) {
      _selected
        ..clear()
        ..add(path);
      _anchor = _cursor = path;
    }
    // Only for now: the pane opens to type the tags, it is not the user's setting to keep.
    _previewPane = true;
    _galleryPane = true;
  });

  /// The 16 pt icon of an app in Open With (kit `Icons/App/16`), drawn from its own icon; an app
  /// that is not one of Silica's gets an empty box, so the labels of the apps line up.
  Widget _appIcon(DesktopApp app) =>
      AmalfiAppIcon(app.silicaIcon ?? '', env: widget.iconsEnv);

  /// The same icon for the shell's menus (a PNG path, mustache#28): null while it is composed.
  String? _appIconName(DesktopApp app) => widget.menuIcons.appIcon(
    app.silicaIcon,
    scale: View.of(context).devicePixelRatio,
    dark: AmalfiTheme.of(context).isDark,
  );

  /// Asks for the menu icons of every app ahead, so the menus have them when they open.
  void _prefetchMenuIcons() {
    if (!mounted) return;
    unawaited(
      widget.menuIcons.prefetchApps(
        _registry.apps.values.map((app) => app.silicaIcon),
        scale: View.of(context).devicePixelRatio,
        dark: AmalfiTheme.of(context).isDark,
      ),
    );
  }

  /// "Open With ›": the default on top with "(default)", then the others by name, then "Other…"
  /// (R10.1).
  AmalfiMenuAction _openWithMenu(List<Entry> files) {
    final type = _typeOf(files.first);
    final preferred = _registry.defaultFor(type);
    final others = [
      for (final app in _registry.appsFor(type))
        if (app.id != preferred?.id) app,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AmalfiMenuAction(
      l10n.openWith,
      // `Submenu/Open With` in the kit is 192 wide.
      submenuWidth: 192,
      submenu: [
        if (preferred != null)
          AmalfiMenuAction(
            l10n.defaultApp(preferred.name),
            icon: _appIcon(preferred),
            iconName: _appIconName(preferred),
            onSelected: () => _openWith(files, preferred),
          ),
        if (preferred != null && others.isNotEmpty) const AmalfiMenuDivider(),
        for (final app in others)
          AmalfiMenuAction(
            app.name,
            icon: _appIcon(app),
            iconName: _appIconName(app),
            onSelected: () => _openWith(files, app),
          ),
        const AmalfiMenuDivider(),
        AmalfiMenuAction(l10n.otherApp, enabled: false),
      ],
    );
  }

  List<AmalfiMenuEntry> _backgroundMenu() => [
    AmalfiMenuAction(l10n.newFolder, onSelected: _newFolder),
    AmalfiMenuAction(
      l10n.pasteItems(FileClipboard.paths.length),
      enabled: FileClipboard.paths.isNotEmpty,
      onSelected: () => _paste(move: false),
    ),
    const AmalfiMenuDivider(),
    AmalfiMenuAction(
      l10n.showInfo,
      onSelected: () => _openInfo([_history.current]),
    ),
    const AmalfiMenuDivider(),
    AmalfiMenuAction(
      l10n.view,
      submenu: [
        AmalfiMenuAction(
          l10n.viewIcons,
          checked: _view == ViewMode.icons,
          onSelected: () => _setView(ViewMode.icons),
        ),
        AmalfiMenuAction(
          l10n.viewList,
          checked: _view == ViewMode.list,
          onSelected: () => _setView(ViewMode.list),
        ),
        AmalfiMenuAction(
          l10n.viewColumns,
          checked: _view == ViewMode.columns,
          onSelected: () => _setView(ViewMode.columns),
        ),
        AmalfiMenuAction(
          l10n.viewGallery,
          checked: _view == ViewMode.gallery,
          onSelected: () => _setView(ViewMode.gallery),
        ),
      ],
    ),
    AmalfiMenuAction(
      l10n.sortBy,
      submenu: [
        // In the icon view also "None" (free positions) and Snap to Grid.
        if (_view == ViewMode.icons) ...[
          AmalfiMenuAction(
            l10n.sortNone,
            checked: _arrangement.free,
            onSelected: _sortNone,
          ),
          AmalfiMenuAction(
            l10n.snapToGrid,
            checked: _arrangement.snap,
            onSelected: _toggleSnap,
          ),
          const AmalfiMenuDivider(),
        ],
        for (final (key, label) in _sortChoices)
          AmalfiMenuAction(
            label,
            checked:
                _sort == key && !(_view == ViewMode.icons && _arrangement.free),
            onSelected: () => _sortBy(key),
          ),
      ],
    ),
    // Clean Up works on free positions; Clean Up By also turns a sorted folder into a free one.
    if (_view == ViewMode.icons) ...[
      const AmalfiMenuDivider(),
      AmalfiMenuAction(
        l10n.cleanUp,
        enabled: _arrangement.free,
        onSelected: _cleanUp,
      ),
      AmalfiMenuAction(
        l10n.cleanUpSelection,
        enabled: _arrangement.free && _selected.isNotEmpty,
        onSelected: () => _cleanUp(selection: true),
      ),
      AmalfiMenuAction(
        l10n.cleanUpBy,
        submenu: [
          for (final (key, label) in _sortChoices)
            AmalfiMenuAction(
              label,
              shortcut: '⌥⌘${arrangeByDigit[key]}',
              onSelected: () => _arrangeBy(key),
            ),
        ],
      ),
    ],
  ];

  List<(SortKey, String)> get _sortChoices => [
    (SortKey.name, l10n.sortName),
    (SortKey.kind, l10n.sortKind),
    (SortKey.modified, l10n.sortModified),
    (SortKey.size, l10n.sortSize),
  ];
}
