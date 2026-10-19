import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:mustache/src/apps.dart';
import 'package:mustache/src/l10n.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory root;
  late Map<String, String> env;

  void app(String id, String text) {
    final file = File('${root.path}/data/applications/$id')
      ..createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-app');
    env = {
      'HOME': root.path,
      'XDG_DATA_HOME': '${root.path}/data',
      'XDG_DATA_DIRS': '${root.path}/sys',
      'XDG_CONFIG_HOME': '${root.path}/config',
      'XDG_CONFIG_DIRS': '${root.path}/etc',
    };
    app('editor.desktop', '''
[Desktop Entry]
Type=Application
Name=Editor
Name[it]=Editor di testo
Exec=editor --new-window %U
MimeType=text/plain;
''');
    app('visore.desktop', '''
[Desktop Entry]
Type=Application
Name=Visore
Exec="/opt/il visore/bin" %f
MimeType=text/plain;image/png;
''');
    app('nascosta.desktop', '''
[Desktop Entry]
Type=Application
Name=Nascosta
Exec=nascosta
NoDisplay=true
MimeType=text/plain;
''');
    app('sub/codice.desktop', '''
[Desktop Entry]
Type=Application
Name=Codice
Exec=codice
MimeType=text/x-csrc;
''');
    File('${root.path}/config/mimeapps.list')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
[Default Applications]
image/png=visore.desktop;
[Removed Associations]
text/plain=editor.desktop;
''');
  });

  tearDown(() => root.deleteSync(recursive: true));

  final mime = MimeDatabase.fromText(
    globs2: '50:text/plain:*.txt\n50:text/x-csrc:*.c\n',
    subclasses: 'text/x-csrc text/plain\n',
  );

  test(
    '.desktop entries: translated name, hidden ones, ids with subdirectories',
    () {
      // The name in the user's language (Name[it] in Italian), Name otherwise.
      expect(
        AppRegistry.load(env: env, mime: mime).apps['editor.desktop']?.name,
        'Editor',
      );
      useLocale(const Locale('it'));
      addTearDown(() => useLocale(const Locale('en')));
      final registry = AppRegistry.load(env: env, mime: mime);
      expect(registry.apps['editor.desktop']?.name, 'Editor di testo');
      expect(registry.apps.containsKey('nascosta.desktop'), isFalse);
      expect(registry.apps['sub-codice.desktop']?.name, 'Codice');
    },
  );

  test('default, removed, parents and the order of "Apri con"', () {
    final registry = AppRegistry.load(env: env, mime: mime);
    expect(registry.defaultFor('image/png')?.id, 'visore.desktop');
    // The editor is removed for text/plain: the viewer remains.
    expect(
      [for (final a in registry.appsFor('text/plain')) a.id],
      ['visore.desktop'],
    );
    // For C source: first who declares it, then who opens the text/plain parent.
    expect(
      [for (final a in registry.appsFor('text/x-csrc')) a.id],
      ['sub-codice.desktop', 'visore.desktop'],
    );
    expect(registry.defaultFor('application/x-ignoto'), isNull);
  });

  test(
    'the registry\'s apps keep the associations; bundles by their entry id',
    () {
      final registry = AppRegistry.withInstalled(
        const [
          SilicaInstalledApp(
            id: 'dev.example.Viewer',
            name: 'Viewer',
            kind: SilicaInstalledAppKind.bundle,
            exec: 'silica-launch /Applications/Viewer.app %U',
            mimeTypes: ['image/png', 'text/plain'],
            silicaIcon: '/Applications/Viewer.app/Contents/Resources/icon',
          ),
          SilicaInstalledApp(
            id: 'visore',
            name: 'Visore',
            desktopFile: '/data/applications/visore.desktop',
            exec: 'visore %f',
            mimeTypes: ['image/png'],
          ),
          SilicaInstalledApp(
            id: 'helper',
            name: 'Helper',
            exec: 'helper',
            noDisplay: true,
            mimeTypes: ['image/png'],
          ),
        ],
        env: env,
        mime: mime,
      );
      expect(registry.apps.keys.toSet(), {
        'silica-bundles-dev.example.Viewer.desktop',
        'visore.desktop',
      });
      final viewer =
          registry.apps['silica-bundles-dev.example.Viewer.desktop']!;
      expect(viewer.appId, 'dev.example.Viewer');
      // mimeapps.list still decides the default.
      expect(registry.defaultFor('image/png')?.id, 'visore.desktop');
      expect(
        [for (final a in registry.appsFor('image/png')) a.name],
        ['Viewer', 'Visore'],
      );
      expect(registry.defaultFor('text/plain')?.appId, 'dev.example.Viewer');
    },
  );

  test('Exec: field codes, quoting, file at the end', () {
    final registry = AppRegistry.load(env: env, mime: mime);
    expect(
      execArguments(registry.apps['editor.desktop']!, ['/a b.txt', '/c.txt']),
      ['editor', '--new-window', '/a b.txt', '/c.txt'],
    );
    expect(
      execArguments(registry.apps['visore.desktop']!, ['/x.png', '/y.png']),
      ['/opt/il visore/bin', '/x.png'],
    );
    expect(execArguments(registry.apps['sub-codice.desktop']!, ['/m.c']), [
      'codice',
      '/m.c',
    ]);
    expect(
      execArguments(
        const DesktopApp(id: 'p', name: 'P', exec: 'p --sconto=50%% %d'),
        [],
      ),
      ['p', '--sconto=50%'],
    );
  });

  test(
    'a program that does not exist is a message, not an exception',
    () async {
      final error = await launchApp(
        const DesktopApp(id: 'x', name: 'Fantasma', exec: '/non/esiste %f'),
        ['/tmp/a'],
      );
      expect(error, contains('Fantasma'));
    },
  );
}
