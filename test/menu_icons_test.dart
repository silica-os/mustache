import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/menu_icons.dart';

void main() {
  test(
    'app and folder icons are composed once, then given by path (mustache#28)',
    () async {
      var apps = 0;
      var folders = 0;
      final icons = MenuIcons(
        apps: (dir, px, dark) async {
          apps++;
          return '$dir-$px-${dark ? 'dark' : 'light'}.png';
        },
        folders: (path, px, scale, dark) async {
          folders++;
          return path == '/broken' ? throw StateError('no') : '$path-$px.png';
        },
      );
      // Not known yet: asked for, no icon in this menu.
      expect(icons.appIcon('/apps/a/icon', scale: 2, dark: false), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(
        icons.appIcon('/apps/a/icon', scale: 2, dark: false),
        '/apps/a/icon-32-light.png',
      );
      expect(apps, 1);
      // Another appearance is another icon.
      await icons.prefetchApps(['/apps/a/icon'], scale: 1, dark: true);
      expect(
        icons.appIcon('/apps/a/icon', scale: 1, dark: true),
        '/apps/a/icon-16-dark.png',
      );
      // A silica-icons name or nothing: no path to give.
      expect(icons.appIcon('scrivi', scale: 1, dark: false), isNull);
      expect(icons.appIcon(null, scale: 1, dark: false), isNull);
      expect(apps, 2);
      // Folders; a failure gives no icon, and is not asked again.
      expect(icons.folderIcon('/home/a', scale: 1, dark: false), isNull);
      expect(icons.folderIcon('/broken', scale: 1, dark: false), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(
        icons.folderIcon('/home/a', scale: 1, dark: false),
        '/home/a-16.png',
      );
      expect(icons.folderIcon('/broken', scale: 1, dark: false), isNull);
      expect(folders, 2);
    },
  );
}
