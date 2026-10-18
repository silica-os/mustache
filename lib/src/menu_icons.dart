// The icons of the menu rows the shell draws (silica-desktop#241, mustache#28). Menus go to the
// system menu service, and a widget cannot cross to the shell: a row's icon travels as
// `AmalfiMenuAction.iconName`, a symbol name or the path of an image file. App icons (Open With)
// are the PNGs the Thumbnails service composes from each app's `icon/` folder
// (`Thumbnails1.AppIcon`); folder icons (the history menu) its composed folder icons
// (`Thumbnails1.Icon`). They are asked for ahead (the menus are built synchronously) and kept for
// the process; until a path is known the row goes without, as an app without an icon does.

import 'dart:async';

import 'package:silica_ui/silica_ui.dart';

/// Composes the PNG of an app icon: [iconDir] the absolute `icon/` folder of the app, at
/// [sizePx] device pixels, dark or light. Null when it cannot.
typedef AppIconLoader =
    Future<String?> Function(String iconDir, int sizePx, bool dark);

/// Composes the PNG of a folder's icon at [sizePx] device pixels. Null when it cannot.
typedef FolderIconLoader =
    Future<String?> Function(String path, int sizePx, double scale, bool dark);

Future<String?> _serviceAppIcon(String iconDir, int sizePx, bool dark) =>
    SilicaThumbnails.appIcon(
      iconDir,
      sizePx,
      look: dark ? IconAppearance.dark : IconAppearance.light,
    );

Future<String?> _serviceFolderIcon(
  String path,
  int sizePx,
  double scale,
  bool dark,
) async {
  final icon = await SilicaThumbnails.icon(
    Uri.file(path),
    sizePx,
    scale: scale,
    noPreview: true,
    look: dark ? IconAppearance.dark : IconAppearance.light,
  );
  return icon?.path;
}

/// The rows' icon side: 16 pt (kit `Icons/App/16`).
const double menuIconSide = 16;

/// The colourless tag dot of the menus (an outline circle), a symbol the shell draws.
const String tagDotSymbol = 'circle';

/// The icon paths of the menu rows, for every window of the process.
class MenuIcons {
  MenuIcons({AppIconLoader? apps, FolderIconLoader? folders})
    : _apps = apps ?? _serviceAppIcon,
      _folders = folders ?? _serviceFolderIcon;

  /// The process' icons (the menus of every window share them).
  static MenuIcons shared = MenuIcons();

  final AppIconLoader _apps;
  final FolderIconLoader _folders;
  final Map<String, String?> _paths = {};
  final Map<String, Future<void>> _pending = {};

  static int _px(double scale) =>
      (menuIconSide * (scale.isFinite && scale > 0 ? scale : 1)).round();

  /// The PNG of the app icon in [iconDir] (an app's `X-Silica-Icon` folder) for a row at
  /// [scale], or null while it is being composed (it is asked for now) or when there is none.
  String? appIcon(
    String? iconDir, {
    required double scale,
    required bool dark,
  }) {
    if (iconDir == null || !iconDir.startsWith('/')) return null;
    final px = _px(scale);
    return _get('app $iconDir $px $dark', () => _apps(iconDir, px, dark));
  }

  /// The PNG of the icon of the folder at [path] for a row at [scale]; null while it is being
  /// composed (it is asked for now) or when there is none.
  String? folderIcon(String path, {required double scale, required bool dark}) {
    if (!path.startsWith('/')) return null;
    final px = _px(scale);
    return _get(
      'folder $path $px $dark',
      () => _folders(path, px, scale, dark),
    );
  }

  /// Asks for the icons of the app folders [iconDirs]; completes when they are known (or
  /// failed), at most after [limit].
  Future<void> prefetchApps(
    Iterable<String?> iconDirs, {
    required double scale,
    required bool dark,
    Duration limit = const Duration(milliseconds: 250),
  }) {
    final waits = <Future<void>>[];
    for (final dir in iconDirs) {
      if (dir == null || !dir.startsWith('/')) continue;
      appIcon(dir, scale: scale, dark: dark);
      final pending = _pending['app $dir ${_px(scale)} $dark'];
      if (pending != null) waits.add(pending);
    }
    if (waits.isEmpty) return Future.value();
    return Future.wait(waits).timeout(limit, onTimeout: () => const []);
  }

  String? _get(String key, Future<String?> Function() load) {
    if (_paths.containsKey(key)) return _paths[key];
    _pending[key] ??= () async {
      String? path;
      try {
        path = await load();
      } on Object {
        path = null;
      }
      _paths[key] = path;
      _pending.remove(key);
    }();
    return null;
  }
}
