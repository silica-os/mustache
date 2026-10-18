// The Mustache settings kept between launches, in `$XDG_CONFIG_HOME/mustache/settings.json`. A
// missing or unreadable file, or odd values, count as the default settings: never an error.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class Settings extends ChangeNotifier {
  Settings(this.path) {
    _read();
  }

  /// The file in the user's configuration directory.
  factory Settings.forUser(Map<String, String> env) {
    final home = env['HOME'] ?? '/';
    final config = env['XDG_CONFIG_HOME'];
    final base = config == null || config.isEmpty ? '$home/.config' : config;
    return Settings('$base/mustache/settings.json');
  }

  final String path;
  final Map<String, Object?> _data = {};
  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _debounce;

  Map<String, Object?> _readFile() {
    try {
      final data = jsonDecode(File(path).readAsStringSync());
      if (data is Map<String, Object?>) return data;
    } on Object {
      // Missing or damaged: the defaults.
    }
    return {};
  }

  void _read() {
    _data
      ..clear()
      ..addAll(_readFile());
  }

  /// Follows the file: what the Settings window (or another window) changes is picked up and
  /// the listeners are told.
  void watch() {
    if (_watch != null) return;
    try {
      final dir = File(path).parent;
      dir.createSync(recursive: true);
      _watch = dir.watch().listen((event) {
        if (!event.path.endsWith('settings.json')) return;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 80), () {
          final before = jsonEncode(_data);
          _read();
          if (jsonEncode(_data) != before) notifyListeners();
        });
      }, onError: (Object _) {});
    } on FileSystemException {
      // No watching: changes show at the next launch.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _watch?.cancel();
    super.dispose();
  }

  /// The sidebar width of new windows (MU-11: the last one set).
  double? get sidebarWidth {
    final value = _data['sidebarWidth'];
    return value is num && value.isFinite && value > 0
        ? value.toDouble()
        : null;
  }

  set sidebarWidth(double? value) {
    _set('sidebarWidth', value);
  }

  /// The last chosen view (`icons`, `list`), for new windows.
  String? get view {
    final value = _data['view'];
    return value is String ? value : null;
  }

  set view(String? value) {
    _set('view', value);
  }

  /// The path bar is visible (⌥⌘P), for new windows.
  bool? get pathBar {
    final value = _data['pathBar'];
    return value is bool ? value : null;
  }

  set pathBar(bool? value) {
    _set('pathBar', value);
  }

  /// The open sections of the Get Info window (shared by all, R11.1).
  List<String>? get infoSections {
    final value = _data['infoSections'];
    return value is List
        ? [
            for (final v in value)
              if (v is String) v,
          ]
        : null;
  }

  set infoSections(List<String>? value) {
    _set('infoSections', value);
  }

  bool? _bool(String key) {
    final v = _data[key];
    return v is bool ? v : null;
  }

  /// The status bar (⌘') and the preview pane (⇧⌘P) visible.
  bool? get statusBar => _bool('statusBar');
  set statusBar(bool? value) {
    _set('statusBar', value);
  }

  bool? get previewPane => _bool('previewPane');
  set previewPane(bool? value) {
    _set('previewPane', value);
  }

  /// The gallery's own preview pane (open unless the user hid it).
  bool? get galleryPane => _bool('galleryPane');
  set galleryPane(bool? value) {
    _set('galleryPane', value);
  }

  /// The icon size of the icon view.
  double? get iconSide {
    final v = _data['iconSide'];
    return v is num && v >= 16 && v <= 512 ? v.toDouble() : null;
  }

  set iconSide(double? value) {
    _set('iconSide', value);
  }

  /// The saved searches shown in the sidebar: paths of `.search` files.
  List<String> get savedSearches {
    final value = _data['savedSearches'];
    return value is List
        ? [
            for (final v in value)
              if (v is String) v,
          ]
        : const [];
  }

  set savedSearches(List<String> value) => _set('savedSearches', value);

  /// Sets [key] on top of what is in the file now (another process may have written other keys)
  /// and saves; a damaged or read-only file never throws.
  void _set(String key, Object? value) {
    final data = _readFile();
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
    _data
      ..clear()
      ..addAll(data);
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(data));
    } on FileSystemException {
      // Without write permission the setting lasts only for this session.
    }
    notifyListeners();
  }

  List<String> _strings(String key) {
    final v = _data[key];
    return v is List
        ? [
            for (final x in v)
              if (x is String) x,
          ]
        : const [];
  }

  // The Settings window (kit `Apps/Mustache/Settings *`) ------------------------------------

  /// General › New windows show: a place (`home`, `desktop`, `documents`, `downloads`,
  /// `pictures`, `music`, `videos`).
  String get newWindowFolder {
    final v = _data['newWindowFolder'];
    return v is String ? v : 'home';
  }

  set newWindowFolder(String value) => _set('newWindowFolder', value);

  /// General › Open folders in tabs instead of new windows: ⌘N opens a tab.
  bool get tabsForNewWindows => _bool('tabsForNewWindows') ?? false;
  set tabsForNewWindows(bool value) => _set('tabsForNewWindows', value);

  /// Tags › colours (names) not shown in the sidebar.
  List<String> get hiddenTags => _strings('hiddenTags');
  set hiddenTags(List<String> value) => _set('hiddenTags', value);

  /// Tags › Favourite tags: the colours (names) in the order of the circles of the menus.
  List<String> get favouriteTags => _strings('favouriteTags');
  set favouriteTags(List<String> value) => _set('favouriteTags', value);

  /// Tags › Colour folders by tag.
  bool get colourFolders => _bool('colourFolders') ?? true;
  set colourFolders(bool value) => _set('colourFolders', value);

  /// Sidebar › the items (`desktop`, `documents`, …, `home`, `trash`, `tags`) that are hidden.
  List<String> get hiddenSidebar => _strings('hiddenSidebar');
  set hiddenSidebar(List<String> value) => _set('hiddenSidebar', value);

  /// Advanced › Ask for confirmation before changing a file extension / emptying the Trash.
  bool get confirmExtension => _bool('confirmExtension') ?? true;
  set confirmExtension(bool value) => _set('confirmExtension', value);

  bool get confirmEmptyTrash => _bool('confirmEmptyTrash') ?? true;
  set confirmEmptyTrash(bool value) => _set('confirmEmptyTrash', value);

  /// Advanced › Remove items from the Trash after 30 days.
  bool get trashCleanup => _bool('trashCleanup') ?? false;
  set trashCleanup(bool value) => _set('trashCleanup', value);

  /// Advanced › Keep folders on top in windows when sorting by name / on the desktop.
  bool get foldersOnTopWindows => _bool('foldersOnTopWindows') ?? true;
  set foldersOnTopWindows(bool value) => _set('foldersOnTopWindows', value);

  bool get foldersOnTopDesktop => _bool('foldersOnTopDesktop') ?? false;
  set foldersOnTopDesktop(bool value) => _set('foldersOnTopDesktop', value);

  /// Advanced › When searching, search in: `computer` or `folder`.
  String get searchScope {
    final v = _data['searchScope'];
    return v == 'folder' ? 'folder' : 'computer';
  }

  set searchScope(String value) => _set('searchScope', value);
}
