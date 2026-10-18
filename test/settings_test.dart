import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/folder_style.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/operations.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/settings_view.dart';
import 'package:mustache/src/sidebar.dart';
import 'package:mustache/src/tags.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart' show AmalfiPopUpButton;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-settings');
    for (final name in ['Documents', 'Downloads', 'Music', 'Desktop']) {
      Directory('${root.path}/$name').createSync();
    }
  });
  tearDown(() {
    windowsFoldersOnTop = true;
    folderStyles.colourByTag = true;
    root.deleteSync(recursive: true);
  });

  group('the settings file', () {
    test('defaults, round trip, and writes that keep what others wrote', () {
      final path = '${root.path}/s.json';
      final a = Settings(path);
      final b = Settings(path);
      expect(a.confirmEmptyTrash, isTrue);
      expect(a.trashCleanup, isFalse);
      expect(a.foldersOnTopWindows, isTrue);
      expect(a.foldersOnTopDesktop, isFalse);
      expect(a.colourFolders, isTrue);
      expect(a.searchScope, 'computer');
      expect(a.newWindowFolder, 'home');
      a.confirmEmptyTrash = false;
      // b holds an older copy: its write must not undo a's.
      b.trashCleanup = true;
      final c = Settings(path);
      expect(c.confirmEmptyTrash, isFalse);
      expect(c.trashCleanup, isTrue);
      c.hiddenTags = ['red'];
      expect(Settings(path).hiddenTags, ['red']);
    });

    test('odd values are the defaults', () {
      final path = '${root.path}/odd.json';
      File(path).writeAsStringSync(
        '{"hiddenTags": 3, "searchScope": "x", "confirmExtension": "no"}',
      );
      final s = Settings(path);
      expect(s.hiddenTags, isEmpty);
      expect(s.searchScope, 'computer');
      expect(s.confirmExtension, isTrue);
    });

    test(
      'listeners hear a change made in the file by another process',
      () async {
        Directory('${root.path}/w').createSync();
        final path = '${root.path}/w/settings.json';
        final s = Settings(path)..watch();
        addTearDown(s.dispose);
        var heard = 0;
        s.addListener(() => heard++);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        File(path).writeAsStringSync('{"trashCleanup": true}');
        for (var i = 0; i < 40 && heard == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(heard, greaterThan(0));
        expect(s.trashCleanup, isTrue);
      },
    );

    test(
      'an atomic replace of the file (write elsewhere, rename over) is heard too',
      () async {
        // Editors, `sed -i`, Settings and other tools write a temporary file and rename it
        // over settings.json: the watcher sees a move whose source is the temporary name.
        Directory('${root.path}/m').createSync();
        final path = '${root.path}/m/settings.json';
        File(path).writeAsStringSync('{"view": "icons", "previewPane": true}');
        final s = Settings(path)..watch();
        addTearDown(s.dispose);
        expect(s.previewPane, isTrue);
        var heard = 0;
        s.addListener(() => heard++);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        File('${root.path}/m/.settings.json.tmp')
          ..writeAsStringSync('{"view": "icons"}')
          ..renameSync(path);
        for (var i = 0; i < 40 && heard == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(heard, greaterThan(0));
        expect(s.previewPane, isNull);
      },
    );

    test('favourite order puts the named colours first', () {
      expect(favouriteOrder(const []), TagColor.values);
      expect(favouriteOrder(['blue', 'x', 'blue', 'red']).take(3), [
        TagColor.blue,
        TagColor.red,
        TagColor.orange,
      ]);
    });

    test('where new windows open', () {
      final places = [
        const Place('casa', '/h', PlaceKind.home),
        const Place('Documents', '/h/Documents', PlaceKind.documents),
      ];
      expect(newWindowPath(null, places, '/x'), '/h');
      expect(newWindowPath('documents', places, '/x'), '/h/Documents');
      expect(newWindowPath('music', places, '/x'), '/x');
    });
  });

  group('folders on top', () {
    final entries = [
      for (final (name, dir) in [
        ('b.txt', false),
        ('Alfa', true),
        ('a.txt', false),
        ('Zeta', true),
      ])
        Entry(
          name: name,
          path: '/$name',
          isDirectory: dir,
          size: 0,
          modified: DateTime(2026),
        ),
    ];
    List<String> names(bool? on, {bool descending = false}) => [
      for (final e in sortEntries(
        entries,
        SortKey.name,
        descending: descending,
        foldersFirst: on,
      ))
        e.name,
    ];

    test('by name the folders come first, also reversed', () {
      expect(names(true), ['Alfa', 'Zeta', 'a.txt', 'b.txt']);
      expect(names(true, descending: true), ['Zeta', 'Alfa', 'b.txt', 'a.txt']);
      expect(names(false), ['a.txt', 'Alfa', 'b.txt', 'Zeta']);
      expect(names(false, descending: true), [
        'Zeta',
        'b.txt',
        'Alfa',
        'a.txt',
      ]);
    });

    test('other sorts are not changed', () {
      final bySize = sortEntries(entries, SortKey.size, foldersFirst: true);
      expect(bySize.first.isDirectory, isTrue);
    });
  });

  group('the Trash cleanup', () {
    test('removes what was deleted more than 30 days ago, keeps the rest', () {
      final trash = Trash('${root.path}/Trash');
      Directory(trash.files).createSync(recursive: true);
      Directory(trash.info).createSync(recursive: true);
      void put(String name, DateTime when, {bool folder = false}) {
        if (folder) {
          Directory('${trash.files}/$name').createSync();
          File('${trash.files}/$name/inside.txt').writeAsStringSync('x');
        } else {
          File('${trash.files}/$name').writeAsStringSync('x');
        }
        File('${trash.info}/$name.trashinfo').writeAsStringSync(
          '[Trash Info]\nPath=/x/$name\nDeletionDate=${when.toIso8601String()}\n',
        );
      }

      final now = DateTime(2026, 10, 17, 12);
      put('old.txt', now.subtract(const Duration(days: 31)));
      put('oldfolder', now.subtract(const Duration(days: 90)), folder: true);
      put('fresh.txt', now.subtract(const Duration(days: 29)));
      File('${trash.files}/nodate.txt').writeAsStringSync('x');
      File(
        '${trash.info}/nodate.txt.trashinfo',
      ).writeAsStringSync('[Trash Info]');
      final removed = trash.purgeOlderThan(const Duration(days: 30), now: now);
      expect(removed, 2);
      expect(File('${trash.files}/old.txt').existsSync(), isFalse);
      expect(File('${trash.info}/old.txt.trashinfo').existsSync(), isFalse);
      expect(Directory('${trash.files}/oldfolder').existsSync(), isFalse);
      expect(File('${trash.files}/fresh.txt').existsSync(), isTrue);
      expect(File('${trash.files}/nodate.txt').existsSync(), isTrue);
    });

    test('no Trash is no error', () {
      expect(
        Trash('${root.path}/none').purgeOlderThan(const Duration(days: 1)),
        0,
      );
    });
  });

  final places = [
    const Place('casa', '/h', PlaceKind.home),
    const Place('Desktop', '/h/Desktop', PlaceKind.desktop),
    const Place('Documents', '/h/Documents', PlaceKind.documents),
    const Place('Downloads', '/h/Downloads', PlaceKind.downloads),
    const Place('Music', '/h/Music', PlaceKind.music),
  ];

  Future<Settings> pumpView(
    WidgetTester tester, {
    SettingsPane pane = SettingsPane.general,
    List<double>? heights,
  }) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings('${root.path}/view.json');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: settingsWidth,
                  child: SettingsView(
                    settings: settings,
                    places: places,
                    initial: pane,
                    onHeight: heights?.add,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return settings;
  }

  group('the Settings window', () {
    testWidgets('the toolbar: four panes, 56 x 44 at y 4, 8 apart, centred', (
      tester,
    ) async {
      await pumpView(tester);
      final rects = [
        for (final p in SettingsPane.values)
          tester.getRect(find.byKey(ValueKey('settings pane ${p.name}'))),
      ];
      expect(rects[0].top, 4);
      expect(rects[0].size, const Size(56, 44));
      expect(rects[0].left, 176);
      expect(rects[1].left, 240);
      expect(rects[2].left, 304);
      expect(rects[3].left, 368);
    });

    testWidgets('General: the pane is as tall as its rows', (tester) async {
      final heights = <double>[];
      await pumpView(tester, heights: heights);
      // 52 + 24 + heading 16 + 4 + rows 40 + 36 + 24.
      expect(heights.last, 52 + 24 + 20 + 76 + 24);
      // Kit: a pop-up row at x 24, 552 wide; the pop-up 108 wide.
      final row = tester.getRect(
        find.byKey(const ValueKey('setting new window folder')),
      );
      expect(row.left, 24);
      expect(row.width, 552);
      expect(row.top, 96);
    });

    testWidgets('General: the choices are written', (tester) async {
      final s = await pumpView(tester);
      await tester.tap(find.byKey(const ValueKey('setting tabs')));
      await tester.pump();
      expect(s.tabsForNewWindows, isTrue);
      expect(Settings('${root.path}/view.json').tabsForNewWindows, isTrue);
    });

    testWidgets('Tags: rows of 32, the colours shown, favourites, switch', (
      tester,
    ) async {
      final heights = <double>[];
      final s = await pumpView(
        tester,
        pane: SettingsPane.tags,
        heights: heights,
      );
      // Kit Tags: 500 tall with the hidden-free rows (7 × 32, 64, 40).
      expect(heights.last, 500);
      final red = tester.getRect(find.byKey(const ValueKey('setting tag red')));
      final orange = tester.getRect(
        find.byKey(const ValueKey('setting tag orange')),
      );
      expect(orange.top - red.top, 32);
      await tester.tap(find.byKey(const ValueKey('setting tag yellow')));
      await tester.pump();
      expect(s.hiddenTags, ['yellow']);
      await tester.tap(find.byKey(const ValueKey('setting tag yellow')));
      await tester.pump();
      expect(s.hiddenTags, isEmpty);
      await tester.tap(find.byKey(const ValueKey('setting colour folders')));
      await tester.pump();
      expect(s.colourFolders, isFalse);
      // Discs: 26 pt at a 34 pitch.
      final first = tester.getRect(find.byKey(const ValueKey('favourite red')));
      final second = tester.getRect(
        find.byKey(const ValueKey('favourite orange')),
      );
      expect(first.size, const Size(26, 26));
      expect(second.left - first.left, 34);
    });

    testWidgets('Tags: dragging a favourite reorders and saves', (
      tester,
    ) async {
      final s = await pumpView(tester, pane: SettingsPane.tags);
      final red = find.byKey(const ValueKey('favourite red'));
      await tester.drag(red, const Offset(34 * 2 + 4, 0));
      await tester.pump();
      expect(s.favouriteTags.take(3), ['orange', 'yellow', 'red']);
      expect(favouriteOrder(s.favouriteTags).first, TagColor.orange);
    });

    testWidgets('Sidebar: one row per item, written to hiddenSidebar', (
      tester,
    ) async {
      final heights = <double>[];
      final s = await pumpView(
        tester,
        pane: SettingsPane.sidebar,
        heights: heights,
      );
      expect(
        find.byKey(const ValueKey('setting sidebar music')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setting sidebar videos')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('setting sidebar music')));
      await tester.pump();
      expect(s.hiddenSidebar, ['music']);
      await tester.tap(find.byKey(const ValueKey('setting sidebar tags')));
      await tester.pump();
      expect(s.hiddenSidebar, containsAll(['music', 'tags']));
    });

    testWidgets('Advanced: every row is written', (tester) async {
      final s = await pumpView(tester, pane: SettingsPane.advanced);
      for (final key in [
        'setting confirm extension',
        'setting confirm trash',
        'setting trash cleanup',
        'setting folders windows',
        'setting folders desktop',
      ]) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump();
      }
      expect(s.confirmExtension, isFalse);
      expect(s.confirmEmptyTrash, isFalse);
      expect(s.trashCleanup, isTrue);
      expect(s.foldersOnTopWindows, isFalse);
      expect(s.foldersOnTopDesktop, isTrue);
    });

    testWidgets('Advanced: the search scope pop-up', (tester) async {
      final s = await pumpView(tester, pane: SettingsPane.advanced);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('setting search scope')),
          matching: find.byType(AmalfiPopUpButton<String>),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Current folder').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(s.searchScope, 'folder');
    });
  });

  Future<Settings> pumpWindow(WidgetTester tester, {Settings? settings}) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final used = settings ?? Settings('${root.path}/settings.json');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [
            Place('casa', root.path, PlaceKind.home),
            Place('Documents', '${root.path}/Documents', PlaceKind.documents),
            Place('Music', '${root.path}/Music', PlaceKind.music),
          ],
          trash: Place('Trash', '${root.path}/Trash', PlaceKind.trash),
          settings: used,
        ),
      ),
    );
    await tester.pump();
    return used;
  }

  group('the window follows the settings', () {
    testWidgets('hidden sidebar items and tags disappear, and come back', (
      tester,
    ) async {
      final s = await pumpWindow(tester);
      Finder row(String label) =>
          find.descendant(of: find.byType(Sidebar), matching: find.text(label));
      expect(row('Music'), findsOneWidget);
      expect(row('Red'), findsOneWidget);
      expect(row('Trash'), findsOneWidget);
      s.hiddenSidebar = ['music', 'trash'];
      s.hiddenTags = ['red'];
      await tester.pump();
      expect(row('Music'), findsNothing);
      expect(row('Trash'), findsNothing);
      expect(row('Red'), findsNothing);
      expect(row('Orange'), findsOneWidget);
      s.hiddenSidebar = ['tags'];
      await tester.pump();
      expect(row('Music'), findsOneWidget);
      expect(row('Orange'), findsNothing);
      expect(row('Documents'), findsOneWidget);
    });

    testWidgets('colour folders by tag off: the folders lose their tint', (
      tester,
    ) async {
      final s = await pumpWindow(tester);
      expect(folderStyles.colourByTag, isTrue);
      s.colourFolders = false;
      await tester.pump();
      expect(folderStyles.colourByTag, isFalse);
    });

    testWidgets('keeping folders on top is applied at launch and live', (
      tester,
    ) async {
      final s = Settings('${root.path}/settings.json')
        ..foldersOnTopWindows = false;
      await pumpWindow(tester, settings: s);
      expect(windowsFoldersOnTop, isFalse);
      s.foldersOnTopWindows = true;
      await tester.pump();
      expect(windowsFoldersOnTop, isTrue);
    });
  });
}
