// The icons of the menu rows the shell draws (silica-desktop#241, mustache#28). Menus go to the
// system menu service, and a widget cannot cross to the shell: a row's icon travels as
// `AmalfiMenuAction.iconName`, a symbol name or the path of an image file. App icons (Open With)
// are the PNGs the Thumbnails service composes from each app's `icon/` folder
// (`Thumbnails1.AppIcon`); folder icons (the history menu) its composed folder icons
// (`Thumbnails1.Icon`). They are asked for ahead (the menus are built synchronously) and kept for
// the process; until a path is known the row goes without, as an app without an icon does.

import 'dart:async';
import 'dart:io';

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

  final Map<String, String?> _themed = {};

  /// The icon of an app that is not one of Silica's, from its desktop entry's `Icon`: an
  /// absolute PNG, or the PNG of that name in the hicolor icon theme of the data directories
  /// of [env] (the size nearest to a row at [scale] first) or in `pixmaps`. Null when there is
  /// none the shell can draw (the row keeps an empty box).
  String? themeIcon(
    String? name, {
    required double scale,
    Map<String, String>? env,
  }) {
    if (name == null || name.isEmpty) return null;
    final px = _px(scale);
    final key = '$name $px';
    if (_themed.containsKey(key)) return _themed[key];
    String? found;
    if (name.startsWith('/')) {
      found = name.endsWith('.png') && File(name).existsSync() ? name : null;
    } else if (!name.contains('/')) {
      // From the size of the row up, then the smaller ones.
      final sizes = [16, 22, 24, 32, 48, 64, 128, 256, 512]
        ..sort((a, b) {
          int rank(int s) => s >= px ? s - px : 10000 + px - s;
          return rank(a).compareTo(rank(b));
        });
      final dirs = xdgDataDirs(env ?? Platform.environment);
      outer:
      for (final size in sizes) {
        for (final dir in dirs) {
          final path = '$dir/icons/hicolor/${size}x$size/apps/$name.png';
          if (File(path).existsSync()) {
            found = path;
            break outer;
          }
        }
      }
      if (found == null) {
        for (final dir in dirs) {
          final path = '$dir/pixmaps/$name.png';
          if (File(path).existsSync()) {
            found = path;
            break;
          }
        }
      }
    }
    return _themed[key] = found;
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
