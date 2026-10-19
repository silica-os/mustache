// Get Info as real windows (mustache#12): one child window of the Mustache window per item,
// which can be dragged anywhere and stays open while the browser window is used, as on the
// reference. Silica opens them with `SilicaWindows.openWindow` (silica-desktop#146); where it
// cannot (the desktop layer, an older Silica) the panels are drawn inside this window.

part of 'window.dart';

/// A Get Info window: the item it shows (a rename changes it) and its window.
class _InfoWindow {
  _InfoWindow(this.path);

  String path;
  SilicaWindowController? controller;
}

/// The height of a Get Info window is its content's, between these.
const double _infoMinHeight = 160;
const double _infoMaxHeight = 900;

extension _InfoWindows on _MustacheWindowState {
  /// Opens the Get Info windows (at most 5): real windows when Silica can open them, the panels
  /// inside this window otherwise. An item already shown is not opened twice.
  void _openInfo(List<String> paths) {
    for (final path in paths.take(5)) {
      if (_infos.contains(path) || _infoWindows.any((w) => w.path == path)) {
        continue;
      }
      _openInfoWindow(path);
    }
  }

  Future<void> _openInfoWindow(String path) async {
    final info = _InfoWindow(path);
    _infoWindows.add(info);
    final window = await SilicaWindows.openWindow(
      title: l10n.infoTitle(displayName(path)),
      size: const Size(infoWidth, 520),
      minSize: const Size(infoWidth, _infoMinHeight),
      maxSize: const Size(infoWidth, _infoMaxHeight),
      kind: SilicaWindowKind.utility,
      parent: View.maybeOf(context)?.viewId ?? 0,
      builder: (context) => _infoWindowContent(info),
    );
    if (window == null) {
      // No windows here: the panel inside this window.
      _infoWindows.remove(info);
      if (mounted && !_infos.contains(info.path)) {
        _update(() => _infos.add(info.path));
      }
      return;
    }
    if (!mounted) {
      await window.close();
      return;
    }
    info.controller = window;
    unawaited(window.closed.then((_) => _infoWindows.remove(info)));
  }

  /// The content of a Get Info window: the panel without its frame, rebuilt when a section opens
  /// or the item is renamed.
  Widget _infoWindowContent(_InfoWindow info) => ValueListenableBuilder<int>(
    valueListenable: _infoRevision,
    builder: (context, _, _) {
      final entry = entryAt(info.path);
      // The item is gone (deleted, moved away): an empty window until it is closed.
      if (entry == null) {
        return ColoredBox(color: AmalfiTheme.of(context).colors.surfaceWindow);
      }
      return InfoPanel(
        key: ValueKey(info.path),
        framed: false,
        entry: entry,
        kind: _kind(entry),
        mime: entry.isDirectory ? null : _typeOf(entry),
        env: widget.iconsEnv,
        open: _infoOpen,
        app: _appDetailsOf(entry),
        openWith: entry.isDirectory
            ? null
            : _registry.defaultFor(_typeOf(entry))?.name,
        onToggle: _toggleInfoSection,
        tags: _tagsOf(entry),
        onAddTag: (tag) => _addTag(entry, tag),
        onTagsChanged: (tags) => _setTagList(entry, tags),
        onClose: () => info.controller?.close(),
        onRename: (name) {
          final old = info.path;
          final result = renameEntry(old, name);
          if (result.error != null) {
            _showError(l10n.cantRename, result.error);
            return;
          }
          _undo.push(RenameOp(old, result.path!));
          info.path = result.path!;
          info.controller?.setTitle(l10n.infoTitle(displayName(info.path)));
          _infoRevision.value++;
          _load();
        },
        onHeight: (height) => info.controller?.setSize(
          Size(infoWidth, height.clamp(_infoMinHeight, _infoMaxHeight)),
        ),
      );
    },
  );

  /// Get Info's details when `entry` is an app (a bundle, or a Flatpak app of the Applications
  /// view): from the cache, else null while they are read (the panel shows them when they come).
  AppDetails? _appDetailsOf(Entry entry) {
    final flatpak = _flatpaks[entry.path];
    if (flatpak == null && !(entry.isDirectory && isAppBundle(entry.path))) {
      return null;
    }
    if (_appDetails[entry.path] case final cached?) return cached;
    if (_appDetailsLoading.add(entry.path)) {
      unawaited(_loadAppDetails(entry.path, flatpak));
    }
    return null;
  }

  Future<void> _loadAppDetails(String path, SilicaInstalledApp? flatpak) async {
    final AppDetails details;
    if (flatpak != null) {
      details = AppDetails(
        version: flatpak.version,
        developer: flatpak.developer,
        signature: l10n.signatureFlatpak,
      );
    } else {
      final app = _installed[path];
      // The verdict of Gatekeeper on the bundle as it is now (its signature, its files).
      final assessment = await SilicaTrust.assess(path);
      final system = isSystemApp(path);
      details = AppDetails(
        version: app?.version ?? bundleVersion(path) ?? '',
        developer: app?.developer ?? '',
        signature: assessment == null ? '' : signatureLabel(assessment.info),
        access: accessLabel(app?.permissions ?? const {}, system: system),
      );
    }
    _appDetailsLoading.remove(path);
    if (!mounted) return;
    _appDetails[path] = details;
    _infoRevision.value++;
    _update(() {});
  }

  /// A section opens or closes in every Get Info (R11.1), windows and panels alike, and the
  /// choice is kept.
  void _toggleInfoSection(InfoSection section) {
    _update(() {
      _infoOpen.contains(section)
          ? _infoOpen.remove(section)
          : _infoOpen.add(section);
    });
    _infoRevision.value++;
    widget.settings?.infoSections = [for (final s in _infoOpen) s.name];
  }

  /// This window goes: its Get Info windows go with it (they show its items and act on them).
  void _closeInfoWindows() {
    for (final info in [..._infoWindows]) {
      info.controller?.close();
    }
    _infoWindows.clear();
  }
}
