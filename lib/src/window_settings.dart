// What the Settings window changes (docs: kit `Apps/Mustache/Settings *`): the window follows
// settings.json, which the Settings window and the other windows write; here is what that does
// to this window, and the Settings window itself.

part of 'window.dart';

/// The Settings window, if one is open (one for the app).
SilicaWindowController? _settingsWindow;

extension _SettingsEffects on _MustacheWindowState {
  /// A sidebar item (a place kind's name, or `tags`) is shown (Settings › Sidebar).
  bool _sidebarShows(String id) =>
      !(widget.settings?.hiddenSidebar.contains(id) ?? false);

  void _startSettings() {
    final s = widget.settings;
    if (s == null) return;
    s.addListener(_settingsChanged);
    _applySettings(s);
    _searchScope = s.searchScope == 'folder'
        ? SearchScope.folder
        : SearchScope.computer;
    // Settings › Advanced: items in the Trash for more than 30 days go.
    if (s.trashCleanup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_trash.purgeOlderThan(const Duration(days: 30)) > 0 &&
            _trash.contains(_history.current)) {
          _load();
        }
      });
    }
  }

  void _applySettings(Settings s) {
    windowsFoldersOnTop = s.foldersOnTopWindows;
    folderStyles.colourByTag = s.colourFolders;
    _foldersOnTop = s.foldersOnTopWindows;
  }

  /// settings.json changed (this window, the Settings window, another window).
  void _settingsChanged() {
    final s = widget.settings;
    if (s == null || !mounted) return;
    final resort = s.foldersOnTopWindows != _foldersOnTop;
    _applySettings(s);
    if (!_searching && _searchQuery.text.isEmpty) {
      _searchScope = s.searchScope == 'folder'
          ? SearchScope.folder
          : SearchScope.computer;
    }
    _update(() {
      if (resort && !_searching && _tagView == null) {
        _entries = sortEntries(
          _entries,
          _sort,
          descending: _descending,
          kindOf: _kind,
        );
      }
    });
    _queueMenus();
  }

  /// App › Settings… (⌘,): a window of 600 pt, as tall as its pane; where Silica cannot open
  /// windows the settings are a sheet of this one.
  Future<void> _openSettings() async {
    final s = widget.settings;
    if (s == null || _settingsWindow?.isOpen == true) return;
    s.watch();
    SilicaWindowController? window;
    Widget view(BuildContext context) => SettingsView(
      settings: s,
      places: widget.places,
      onHeight: (h) {
        final w = window;
        if (w == null) return;
        final size = Size(settingsWidth, h);
        unawaited(
          w.setSizeLimits(min: size, max: size).then((_) => w.setSize(size)),
        );
      },
      onTitle: (t) => unawaited(window?.setTitle(t) ?? Future.value(false)),
    );
    window = await SilicaWindows.openWindow(
      title: l10n.settingsGeneral,
      size: const Size(settingsWidth, 464),
      toolbarHeight: AmalfiToolbarMetrics.toolbarHeight,
      builder: view,
    );
    if (window == null) {
      if (!mounted || _modalOpen) return;
      _update(() {
        _sheetCentered = true;
        _sheet = SizedBox(
          key: const ValueKey('settings sheet'),
          width: settingsWidth,
          height: 572,
          child: SettingsView(settings: s, places: widget.places),
        );
      });
      return;
    }
    _settingsWindow = window;
    unawaited(window.closed.then((_) => _settingsWindow = null));
  }
}
