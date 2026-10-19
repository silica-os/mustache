// File operations of the window (MU.4): rename, new folder, duplicate, Trash, delete, undo and
// redo, with their alerts.

part of 'window.dart';

/// A slow click on the name of an already selected item starts renaming after ~440 ms
/// (docs/spec/rename.md), unless a double click follows.
const Duration slowClickRename = Duration(milliseconds: 440);

extension _Operations on _MustacheWindowState {
  /// The selection in view order; in columns it can be a folder outside the shown contents (the
  /// open folder).
  List<Entry> get _selection => [
    for (final e in _entries)
      if (_selected.contains(e.path)) e,
    for (final path in _selected)
      if (!_entries.any((e) => e.path == path)) ?entryAt(path),
  ];

  void _select(Iterable<String> paths) {
    _selected
      ..clear()
      ..addAll(paths);
    _anchor = _cursor = paths.isEmpty ? null : paths.last;
  }

  void _showAlert(Widget alert) => _update(() => _alert = alert);

  void _closeAlert() {
    _update(() => _alert = null);
    _focus.requestFocus();
  }

  /// An error: alert with a single OK.
  void _showError(String title, [String? message]) => _showAlert(
    MustacheAlert(
      opaque: true,
      icon: _appIcon,
      title: title,
      message: message,
      buttons: [
        AlertButton(l10n.ok, role: AlertRole.primary, onPressed: _closeAlert),
      ],
    ),
  );

  void _startRename(String path) {
    _slowClick?.cancel();
    // A Flatpak app's item is the app, not a file of the user's: it keeps its name.
    if (_flatpaks.containsKey(path)) return;
    _update(() {
      _select([path]);
      _renaming = path;
    });
  }

  void _endRename() {
    _update(() => _renaming = null);
    _focus.requestFocus();
  }

  /// The name typed in the field: checks (R8.2, R8.3), confirmation if the extension changes
  /// (R8.4), then the rename.
  void _commitRename(Entry entry, String name) {
    _endRename();
    if (name == entry.name) return;
    final dir = parentOf(entry.path) ?? '/';
    final problem = invalidName(dir, entry.name, name);
    if (problem != null) {
      _showError(problem);
      return;
    }
    if (extensionChanges(entry.name, name, isDirectory: entry.isDirectory) &&
        (widget.settings?.confirmExtension ?? true)) {
      final (_, oldExt) = splitExtension(entry.name);
      final (newBase, newExt) = splitExtension(name);
      _showAlert(
        MustacheAlert(
          opaque: true,
          icon: _appIcon,
          title: newExt.isEmpty
              ? l10n.extensionRemove(oldExt)
              : l10n.extensionChange(newExt, oldExt),
          message: l10n.extensionWarning,
          sideBySide: true,
          buttons: [
            AlertButton(
              l10n.keepExtension(oldExt),
              role: AlertRole.cancel,
              onPressed: () {
                _closeAlert();
                _rename(entry, '$newBase$oldExt');
              },
            ),
            AlertButton(
              newExt.isEmpty ? l10n.removeExtension : l10n.useExtension(newExt),
              role: AlertRole.primary,
              onPressed: () {
                _closeAlert();
                _rename(entry, name);
              },
            ),
          ],
        ),
      );
      return;
    }
    _rename(entry, name);
  }

  void _rename(Entry entry, String name) {
    final result = renameEntry(entry.path, name);
    if (result.error != null) {
      _showError(l10n.cantRenameItem(entry.name), result.error);
      return;
    }
    _undo.push(RenameOp(entry.path, result.path!));
    _select([result.path!]);
    _load();
  }

  /// ⇧⌘N: "untitled folder", renamed right away; ⌘Z deletes it.
  void _newFolder() {
    final result = createFolder(_history.current);
    if (result.error != null) {
      _showError(l10n.cantCreateFolder, result.error);
      return;
    }
    final path = result.path!;
    _undo.push(
      CreateOp([path], l10n.newFolder, (p) {
        try {
          Directory(p).createSync();
          return (path: p, error: null);
        } on FileSystemException catch (e) {
          return (path: null, error: e.message);
        }
      }),
    );
    _load();
    _startRename(path);
  }

  /// ⌘D: copies next to the originals; the selection moves to the copies.
  void _duplicate([List<Entry>? items]) {
    final sources = items ?? _selection;
    if (sources.isEmpty) return;
    final made = <String, String>{};
    String? error;
    for (final entry in sources) {
      final result = duplicate(entry.path);
      if (result.error != null) {
        error = result.error;
        break;
      }
      made[result.path!] = entry.path;
    }
    if (made.isNotEmpty) {
      _undo.push(
        CreateOp(
          made.keys.toList(),
          made.length == 1
              ? l10n.opDuplicate
              : l10n.opDuplicateMany(made.length),
          (copy) {
            // Redo: copy again, with the same name.
            final source = made[copy];
            if (source == null) return (path: null, error: l10n.unknownCopy);
            final again = duplicate(source);
            if (again.error != null || again.path == copy) return again;
            return renameEntry(again.path!, displayName(copy));
          },
        ),
      );
      _select(made.keys);
      // The copy is made: the move/copy sound (FILE-SOUNDS).
      unawaited(playUiSound(UiSound.fileTransfer));
    }
    _load();
    if (error != null) _showError(l10n.cantDuplicate, error);
  }

  /// File › Make Link: a symbolic link next to each selected item; the selection moves to them.
  void _makeLink() {
    final sources = _selection;
    if (sources.isEmpty) return;
    final made = <String, String>{};
    String? error;
    for (final entry in sources) {
      final result = makeLink(entry.path);
      if (result.error != null) {
        error = result.error;
        break;
      }
      made[result.path!] = entry.path;
    }
    if (made.isNotEmpty) {
      _undo.push(
        CreateOp(
          made.keys.toList(),
          made.length == 1 ? l10n.opMakeLink : l10n.opMakeLinkMany(made.length),
          (link) {
            final source = made[link];
            if (source == null) return (path: null, error: l10n.unknownCopy);
            final again = makeLink(source);
            if (again.error != null || again.path == link) return again;
            return renameEntry(again.path!, displayName(link));
          },
        ),
      );
      _select(made.keys);
      unawaited(playUiSound(UiSound.fileTransfer));
    }
    _load();
    if (error != null) _showError(l10n.cantMakeLink, error);
  }

  /// File › Show Original: the folder of the link's target, with the target selected.
  void _showOriginal() {
    final items = _selection;
    if (items.length != 1 || !items.first.isLink) return;
    String target;
    try {
      target = Link(items.first.path).resolveSymbolicLinksSync();
    } on FileSystemException {
      _showError(l10n.cantShowOriginal, l10n.errorGone);
      return;
    }
    final parent = parentOf(target);
    if (parent == null) return;
    _navigate(parent);
    _update(() => _select([target]));
  }

  /// ⌘⌫: to the Trash (the selection moves to the next item); inside the Trash, Put Back.
  /// To the Trash: the selected items, or `targets` (the row with the menu ring).
  void _moveToTrash([List<Entry>? targets]) {
    final items = targets ?? _selection;
    if (items.isEmpty) return;
    if (_trash.contains(_history.current)) {
      _restore(items);
      return;
    }
    // Flatpak apps of the Applications view are uninstalled (flatpak uninstall through the
    // registry; the system installation asks for the password), not moved (mustache#32).
    final flatpaks = [
      for (final entry in items)
        if (_flatpaks[entry.path] case final app?) app,
    ];
    if (flatpaks.isNotEmpty) {
      final env = widget.iconsEnv ?? Platform.environment;
      for (final app in flatpaks) {
        if (appRunning(app.id, env)) {
          _showError(l10n.appIsRunning(app.name));
          return;
        }
      }
      unawaited(() async {
        for (final app in flatpaks) {
          if (!await SilicaApps.uninstall(app.id)) {
            if (mounted) _showError(l10n.cantTrash, app.name);
            return;
          }
        }
        if (mounted) unawaited(playUiSound(UiSound.trashMove));
        await _loadApps();
      }());
      return;
    }
    // Apps (silica-os docs/app-bundles.md): the system's stay; an open one is quit first;
    // in /Applications without write permission the helper removes it (polkit).
    final env = widget.iconsEnv ?? Platform.environment;
    for (final entry in items) {
      if (!entry.isDirectory || !isAppBundle(entry.path)) continue;
      final name = entry.name.replaceAll(RegExp(r'\.app$'), '');
      if (isSystemApp(entry.path)) {
        _showError(l10n.appIsSystem(name));
        return;
      }
      if (bundleId(entry.path) case final id? when appRunning(id, env)) {
        _showError(l10n.appIsRunning(name));
        return;
      }
    }
    final privileged = [
      for (final entry in items)
        if (parentOf(entry.path) case final parent?
            when isAppBundle(entry.path) &&
                isApplicationsFolder(parent) &&
                !folderWritable(parent))
          entry,
    ];
    if (privileged.isNotEmpty) {
      unawaited(() async {
        for (final entry in privileged) {
          if (!await removeFromApplications(entry.path)) {
            if (mounted) _showError(l10n.cantTrash, entry.name);
            return;
          }
        }
        if (mounted) _load();
      }());
      return;
    }
    final last = _entries.indexWhere((e) => e.path == items.last.path);
    final moves = <(String, String)>[];
    String? error;
    for (final entry in items) {
      final result = _trash.put(entry.path);
      if (result.error != null) {
        error = result.error;
        break;
      }
      moves.add((entry.path, result.path!));
    }
    if (moves.isNotEmpty) {
      _undo.push(TrashOp(moves));
      // As the items leave the window (FILE-SOUNDS).
      unawaited(playUiSound(UiSound.trashMove));
    }
    // The item after the last removed one, if any, otherwise the one before.
    final gone = {for (final (from, _) in moves) from};
    final rest = [
      for (final e in _entries)
        if (!gone.contains(e.path)) e.path,
    ];
    final next = _entries
        .skip(last + 1)
        .where((e) => !gone.contains(e.path))
        .firstOrNull
        ?.path;
    final pick = next ?? rest.lastOrNull;
    _select([?pick]);
    _load();
    if (error != null) _showError(l10n.cantTrash, error);
  }

  void _restore(List<Entry> items) {
    String? error;
    for (final entry in items) {
      final result = _trash.restore(entry.path);
      if (result.error != null) {
        error = result.error;
        break;
      }
    }
    _select(const []);
    _load();
    if (error != null) _showError(l10n.cantRestore, error);
  }

  /// ⌥⌘⌫: confirmation, then deletes immediately (cannot be undone).
  void _confirmDelete() {
    final items = _selection;
    if (items.isEmpty) return;
    _showAlert(
      MustacheAlert(
        opaque: true,
        icon: _appIcon,
        title: items.length == 1
            ? l10n.confirmDeleteOne(items.first.name)
            : l10n.confirmDeleteMany(items.length),
        message: items.length == 1
            ? l10n.deleteWarningOne
            : l10n.deleteWarningMany,
        sideBySide: true,
        buttons: [
          AlertButton(
            l10n.cancel,
            role: AlertRole.cancel,
            onPressed: _closeAlert,
          ),
          AlertButton(
            l10n.delete,
            role: AlertRole.destructive,
            onPressed: () {
              _closeAlert();
              String? error;
              for (final entry in items) {
                error ??= deletePermanently(entry.path).error;
              }
              _select(const []);
              _load();
              if (error != null) _showError(l10n.cantDelete, error);
            },
          ),
        ],
      ),
    );
  }

  /// App › Empty Trash… (⇧⌘⌫): the alert of the reference (R9.12), then the Trash is emptied.
  void _confirmEmptyTrash() {
    // Settings › Advanced: without the question the Trash is emptied at once.
    if (!(widget.settings?.confirmEmptyTrash ?? true)) {
      final error = _trash.empty();
      _select(const []);
      _load();
      if (error != null) _showError(l10n.cantDelete, error);
      return;
    }
    _showAlert(
      MustacheAlert(
        opaque: true,
        icon: _appIcon,
        title: l10n.confirmEmptyTrash,
        message: l10n.emptyTrashWarning,
        buttons: [
          AlertButton(
            l10n.menuEmptyTrashAction,
            role: AlertRole.primary,
            onPressed: () {
              _closeAlert();
              final error = _trash.empty();
              _select(const []);
              _load();
              if (error != null) _showError(l10n.cantDelete, error);
            },
          ),
          AlertButton(
            l10n.cancel,
            role: AlertRole.cancel,
            onPressed: _closeAlert,
          ),
        ],
      ),
    );
  }

  void _undoLast() {
    final error = _undo.undo(_trash);
    _load();
    if (error != null) _showError(l10n.cantUndo, error);
  }

  void _redoLast() {
    final error = _undo.redo(_trash);
    _load();
    if (error != null) _showError(l10n.cantRedo, error);
  }
}
