import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/app_bundles.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/xattr.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory root;

  Directory bundle(String folder, String name) {
    final dir = Directory('${root.path}/$folder/$name.app/Contents')
      ..createSync(recursive: true);
    File('${dir.path}/Info.toml').writeAsStringSync('format = 1\n');
    Directory('${dir.path}/bin').createSync();
    File('${dir.path}/bin/run').writeAsStringSync('#!/bin/sh\n');
    return dir.parent;
  }

  setUp(() => root = Directory.systemTemp.createTempSync('mustache-apps'));
  tearDown(() => root.deleteSync(recursive: true));

  test('bundles are told from folders', () {
    final app = bundle('a', 'Hello');
    Directory('${root.path}/a/Plain.app').createSync();
    expect(isAppBundle(app.path), isTrue);
    expect(isAppBundle('${root.path}/a/Plain.app'), isFalse);
    expect(isAppBundle('${root.path}/a'), isFalse);
    expect(isApplicationsFolder('/Applications'), isTrue);
    expect(isApplicationsFolder('/var/Applications/'), isTrue);
    expect(isApplicationsFolder('/home/u/Applications'), isFalse);
  });

  test(
    'the Applications view merges the user\'s apps after the shared ones',
    () {
      bundle('home/Applications', 'Mine');
      bundle('home/Applications', 'Shared');
      final env = {'HOME': '${root.path}/home'};
      final own = [
        Entry(
          name: 'Shared.app',
          path: '/Applications/Shared.app',
          isDirectory: true,
          size: 0,
          modified: DateTime(2026),
        ),
      ];
      final merged = mergeApplications(own, env);
      expect(merged.map((e) => e.path), [
        '/Applications/Shared.app',
        '${root.path}/home/Applications/Mine.app',
      ]);
    },
  );

  test('volumes and their quarantine mark', () {
    const volume = SilicaVolume(
      mountpoint: '/run/user/1000/silica-volumes/Hello',
      image: '/home/u/Downloads/Hello 1.0.sxv',
      name: 'Hello',
    );
    expect(
      volumeOf('/run/user/1000/silica-volumes/Hello/Hello.app', [volume]),
      volume,
    );
    expect(volumeOf('/run/user/1000/silica-volumes/Hello 2', [volume]), isNull);
    final mark = volumeQuarantine(
      volume.image,
      now: DateTime.utc(2026, 10, 19),
    );
    expect(mark, startsWith('1;0002;'));
    expect(
      mark,
      endsWith(
        ';dev.frascella.Mustache;file:///home/u/Downloads/Hello%201.0.sxv',
      ),
    );
    expect(
      volumesFolder({'XDG_RUNTIME_DIR': '/run/user/7'}),
      '/run/user/7/silica-volumes',
    );
  });

  test(
    'installing copies the bundle with its mark, and asks before replacing',
    () async {
      final source = bundle('volume', 'Hello');
      final target = Directory('${root.path}/Applications')..createSync();
      final (installed, error) = await installBundle(
        source.path,
        target.path,
        quarantine: '1;0002;0;dev.frascella.Mustache;file:///x.sxv',
      );
      expect(error, isNull);
      expect(installed, '${target.path}/Hello.app');
      expect(File('$installed/Contents/bin/run').existsSync(), isTrue);
      // Marked, where the file system has user attributes.
      final mark = readAttribute(installed!, quarantineAttribute);
      if (mark != null) expect(mark, contains('file:///x.sxv'));
      // Already there: the caller asks; replacing works.
      expect(await installBundle(source.path, target.path), (
        null,
        InstallError.exists,
      ));
      final (again, _) = await installBundle(
        source.path,
        target.path,
        replace: true,
      );
      expect(again, installed);
      expect(target.listSync().map((e) => e.path.split('/').last), [
        'Hello.app',
      ]);
    },
  );

  test('system apps, ids and running apps', () {
    final app = bundle('a', 'Hello');
    File('${app.path}/Contents/Info.toml').writeAsStringSync(
      'format = 1\nid = "dev.example.Hello"\nname = "Hello"\n',
    );
    expect(bundleId(app.path), 'dev.example.Hello');
    expect(isSystemApp('/usr/Applications/Calculator.app'), isTrue);
    expect(isSystemApp('/Applications/Hello.app'), isFalse);
    final runtime = Directory('${root.path}/run/silica-apps')
      ..createSync(recursive: true);
    final env = {'XDG_RUNTIME_DIR': '${root.path}/run'};
    expect(appRunning('dev.example.Hello', env), isFalse);
    File('${runtime.path}/dev.example.Hello.$pid.sock').writeAsStringSync('');
    expect(appRunning('dev.example.Hello', env), isTrue);
    expect(appRunning('dev.example', env), isFalse);
  });

  test('a volume layout places its items and puts the others under it', () {
    Entry e(String name) => Entry(
      name: name,
      path: '/v/$name',
      isDirectory: false,
      size: 0,
      modified: DateTime(2026),
    );
    const layout = SilicaVolumeWindow(
      iconSize: 128,
      items: [
        SilicaVolumeItem('Hello.app', 140, 190),
        SilicaVolumeItem('Applications', 400, 190),
      ],
    );
    final p = volumePositions(
      [e('Hello.app'), e('Applications'), e('LICENSE.txt')],
      layout,
      128,
    );
    expect(p['/v/Hello.app'], const Offset(140, 126));
    expect(p['/v/Applications'], const Offset(400, 126));
    // Under the lowest item, not on it.
    expect(p['/v/LICENSE.txt']!.dy, greaterThan(190 + 64));
  });

  test('a link to Applications counts as Applications', () {
    final link = Link('${root.path}/Applications')
      ..createSync('/var/Applications');
    // The target may not exist here: the name of the link target still says it.
    expect(
      isApplicationsFolder(link.path),
      Directory('/var/Applications').existsSync(),
    );
    expect(isApplicationsFolder('/Applications'), isTrue);
  });

  group('mustache#32', () {
    SilicaInstalledApp flatpak(String id, String name, String file) =>
        SilicaInstalledApp.fromProperties({
          'id': id,
          'name': name,
          'kind': 'flatpak',
          'path': file,
          'desktop_file': file,
          'version': '1.2',
        })!;

    test('Flatpak apps are items of Applications, named after the app', () {
      final exports = Directory('${root.path}/exports/applications')
        ..createSync(recursive: true);
      final firefox = File(
        '${exports.path}/org.mozilla.firefox.desktop',
      )..writeAsStringSync('[Desktop Entry]\nType=Application\nName=Firefox\n');
      File(
        '${exports.path}/org.example.Mine.desktop',
      ).writeAsStringSync('[Desktop Entry]\n');
      bundle('home/Applications', 'Mine');
      final apps = [
        flatpak('org.mozilla.firefox', 'Firefox', firefox.path),
        // A bundle has the name: the bundle stays the item.
        flatpak(
          'org.example.Mine',
          'Mine',
          '${exports.path}/org.example.Mine.desktop',
        ),
        // No entry file: not shown.
        flatpak('org.example.Gone', 'Gone', '${exports.path}/gone.desktop'),
      ];
      final merged = mergeApplications(const [], {
        'HOME': '${root.path}/home',
      }, flatpaks: apps);
      expect(merged.map((e) => e.name), ['Mine.app', 'Firefox']);
      final item = merged.last;
      expect((item.path, item.isDirectory), (firefox.path, false));
      expect(flatpakItems(apps).keys, [
        firefox.path,
        '${exports.path}/org.example.Mine.desktop',
      ]);
    });

    test('Keep Both takes the next free name', () {
      bundle('apps', 'Hello');
      bundle('apps', 'Hello 2');
      expect(keepBothName('${root.path}/apps', 'Hello.app'), 'Hello 3.app');
      expect(keepBothName('${root.path}/apps', 'Other.app'), 'Other 2.app');
    });

    test('Keep Both installs the copy beside the other one', () async {
      final source = bundle('volume', 'Hello');
      bundle('apps', 'Hello');
      final target = '${root.path}/apps';
      final (installed, error) = await installBundle(
        source.path,
        target,
        name: keepBothName(target, 'Hello.app'),
      );
      expect(error, isNull);
      expect(installed, '$target/Hello 2.app');
      expect(isAppBundle('$target/Hello 2.app'), isTrue);
      expect(isAppBundle('$target/Hello.app'), isTrue);
    });

    test('a bundle\'s version, and the disk image window\'s size', () {
      final app = bundle('apps', 'Versioned');
      File(
        '${app.path}/Contents/Info.toml',
      ).writeAsStringSync('format = 1\nversion = "2.4.1"\n');
      expect(bundleVersion(app.path), '2.4.1');
      expect(bundleVersion('${root.path}/none.app'), isNull);
      const layout = SilicaVolumeWindow(width: 540, height: 380);
      // Kit `Apps/Mustache/Volume Window`: the content under a 40 pt title bar.
      expect(volumeWindowSize(layout), const Size(540, 420));
      expect(
        volumeWindowSize(const SilicaVolumeWindow(width: 0, height: 0)),
        isNull,
      );
    });
  });

  test(
    'a running app is found by its live sockets and asked to quit',
    () async {
      final runtime = Directory('${root.path}/run')..createSync();
      Directory('${runtime.path}/silica-apps').createSync();
      final child = await Process.start('sleep', ['30']);
      File(
        '${runtime.path}/silica-apps/org.example.Lemon.${child.pid}.sock',
      ).writeAsStringSync('');
      // A socket of a process that is gone does not count.
      File(
        '${runtime.path}/silica-apps/org.example.Lemon.999999999.sock',
      ).writeAsStringSync('');
      final env = {'XDG_RUNTIME_DIR': runtime.path};
      expect(appPids('org.example.Lemon', env), [child.pid]);
      final quit = quitApp('org.example.Lemon', env);
      await child.exitCode;
      expect(await quit, isTrue);
      expect(appPids('org.example.Lemon', env), isEmpty);
    },
  );
}
