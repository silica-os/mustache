import 'dart:io';

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
}
