import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/list_view.dart';
import 'package:mustache/src/menu_icons.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory home;
  late Directory dir;
  late Map<String, String> env;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    home = Directory.systemTemp.createTempSync('mustache-menu');
    dir = Directory('${home.path}/Documenti')..createSync();
    File('${dir.path}/nota.txt').writeAsStringSync('ciao');
    Directory('${dir.path}/Alfa').createSync();
    env = {
      'HOME': home.path,
      'XDG_DATA_HOME': '${home.path}/.local/share',
      'XDG_DATA_DIRS': '${home.path}/sys',
      'XDG_CONFIG_HOME': '${home.path}/.config',
      'XDG_CONFIG_DIRS': '${home.path}/etc',
      'SILICA_ICONS_DIR': '${home.path}/icons',
    };
    final icon = Directory('${home.path}/icons/apps/scrivi')
      ..createSync(recursive: true);
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024">'
        '<rect width="1024" height="1024" fill="#888"/></svg>';
    File('${icon.path}/background.svg').writeAsStringSync(svg);
    File('${icon.path}/foreground.svg').writeAsStringSync(svg);
    File('${icon.path}/icon.json').writeAsStringSync(
      '{"format":1,"id":"scrivi","name":"Scrivi","kind":"app","keyline":"square",'
      '"layers":[{"role":"background","file":"background.svg"},'
      '{"role":"foreground","file":"foreground.svg"}]}',
    );
    for (final (id, name) in [('scrivi', 'Scrivi'), ('appunti', 'Appunti')]) {
      File('${home.path}/.local/share/applications/$id.desktop')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '[Desktop Entry]\nType=Application\nName=$name\nExec=$id %f\n'
          'MimeType=text/plain;\n'
          '${id == 'scrivi' ? 'X-Silica-Icon=scrivi\n' : ''}',
        );
    }
    File('${home.path}/.config/mimeapps.list')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '[Default Applications]\ntext/plain=scrivi.desktop;\n',
      );
  });

  tearDown(() => home.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: dir.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place(
            'Trash',
            '${home.path}/.local/share/Trash/files',
            PlaceKind.trash,
          ),
          settings: Settings('${home.path}/.config/s.json')..view = 'list',
          iconsEnv: env,
        ),
      ),
    );
  }

  Future<void> rightClick(WidgetTester tester, Offset at) async {
    await tester.tapAt(at, buttons: kSecondaryMouseButton);
    await tester.pump();
  }

  testWidgets(
    'Open With rows carry the app icons by path for the shell\'s menus (mustache#28)',
    (tester) async {
      // As installed: X-Silica-Icon is the app's icon/ folder.
      final iconDir = '${home.path}/apps/scrivi/icon';
      File(
        '${home.path}/.local/share/applications/scrivi.desktop',
      ).writeAsStringSync(
        '[Desktop Entry]\nType=Application\nName=Scrivi\nExec=scrivi %f\n'
        'MimeType=text/plain;\nX-Silica-Icon=$iconDir\n',
      );
      final asked = <(String, int, bool)>[];
      final icons = MenuIcons(
        apps: (dir, px, dark) async {
          asked.add((dir, px, dark));
          return '/cache/apps/${dir.hashCode}-$px.png';
        },
      );
      tester.view.physicalSize = const Size(2000, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: dir.path,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place(
              'Trash',
              '${home.path}/.local/share/Trash/files',
              PlaceKind.trash,
            ),
            settings: Settings('${home.path}/.config/s.json')..view = 'list',
            iconsEnv: env,
            menuIcons: icons,
          ),
        ),
      );
      await tester.pump();
      // Composed ahead, at the window's scale: 16 pt at 2x.
      expect(asked, [(iconDir, 32, false)]);
      await rightClick(tester, tester.getCenter(find.text('nota.txt')));
      final menu = tester.widget<AmalfiMenu>(find.byType(AmalfiMenu).first);
      final openWith = menu.entries.whereType<AmalfiMenuAction>().firstWhere(
        (e) => e.label == 'Open With',
      );
      final rows = openWith.submenu!.whereType<AmalfiMenuAction>().toList();
      expect(rows.first.label, 'Scrivi (default)');
      expect(rows.first.iconName, '/cache/apps/${iconDir.hashCode}-32.png');
      // An app with no icon of its own has none (its label still lines up in the shell).
      expect(rows.firstWhere((r) => r.label == 'Appunti').iconName, isNull);
    },
  );

  testWidgets('file: Open With shows the default on top, then the others', (
    tester,
  ) async {
    await pump(tester);
    final at = tester.getCenter(find.text('nota.txt'));
    await rightClick(tester, at);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Move to Trash'), findsOneWidget);
    // The menu opens with its corner at the pointer (+1, −6), moved inside the window if needed.
    final panel = tester.getRect(find.byType(AmalfiMenu).first);
    expect(panel.topLeft, at + const Offset(1, -6));
    // The Open With submenu.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.moveTo(tester.getCenter(find.text('Open With')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Scrivi (default)'), findsOneWidget);
    expect(find.text('Appunti'), findsOneWidget);
    final defaultTop = tester.getTopLeft(find.text('Scrivi (default)')).dy;
    expect(tester.getTopLeft(find.text('Appunti')).dy, greaterThan(defaultTop));
    expect(tester.getSize(find.byType(AmalfiMenu).last).width, 192);
    // Kit `Submenu/Open With`: 4 pt padding, rows of 24, separators of 8 (default, others, Other…).
    expect(
      tester.getSize(find.byType(AmalfiMenu).last).height,
      4 + 24 + 8 + 24 + 8 + 24 + 4,
    );
    // Kit `Cascade`: the submenu overlaps the parent menu's body by 4 pt.
    expect(
      tester.getRect(find.byType(AmalfiMenu).last).left,
      tester.getRect(find.byType(AmalfiMenu).first).right - 4,
    );
    // Silica's own app has its 16 pt icon; the other apps keep the slot, empty (labels line up).
    expect(find.byType(AmalfiAppIcon), findsNWidgets(2));
    // Its canvas is 16 pt, centred in the menu's icon slot: the body is 824/1024 of it.
    final menuIcon = find.descendant(
      of: find.byType(AmalfiMenu).last,
      matching: find.byType(SilicaIcon),
    );
    expect(menuIcon, findsOneWidget);
    expect(tester.getSize(menuIcon).width, closeTo(12.875, 0.01));
    expect(
      tester.getCenter(menuIcon),
      tester.getCenter(find.byType(AmalfiAppIcon).first),
    );
    expect(
      tester.getTopLeft(find.text('Appunti')).dx,
      tester.getTopLeft(find.text('Scrivi (default)')).dx,
    );
  });

  testWidgets('choosing an app in Open With closes the whole cascade, even when '
      'the app cannot start', (tester) async {
    await pump(tester);
    final at = tester.getCenter(find.text('nota.txt'));
    await rightClick(tester, at);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.moveTo(tester.getCenter(find.text('Open With')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    // `appunti` is not installed: launching it fails (an alert), the menu must still go.
    await tester.tap(find.text('Appunti'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(AmalfiMenu), findsNothing);
  });

  testWidgets('a right click on an unselected row does not select it: ring', (
    tester,
  ) async {
    await pump(tester);
    await rightClick(tester, tester.getCenter(find.text('nota.txt')));
    final rows = tester
        .widgetList<ListRowBackground>(find.byType(ListRowBackground))
        .toList();
    expect(rows.where((r) => r.selected), isEmpty);
    expect(rows.where((r) => r.ring), hasLength(1));
  });

  testWidgets('Move to Trash from the menu, which then closes', (tester) async {
    await pump(tester);
    await rightClick(tester, tester.getCenter(find.text('nota.txt')));
    await tester.tap(find.text('Move to Trash'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(File('${dir.path}/nota.txt').existsSync(), isFalse);
    expect(find.byType(AmalfiMenu), findsNothing);
  });

  testWidgets(
    'the Kind column is the family of the shared-mime-info type (R3.3)',
    (tester) async {
      File('${home.path}/sys/mime/text/plain.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<mime-type type="text/plain"><comment>Plain text</comment>'
          '<comment xml:lang="it">Testo semplice</comment></mime-type>',
        );
      File(
        '${home.path}/sys/mime/globs2',
      ).writeAsStringSync('50:text/plain:*.txt\n');
      await pump(tester);
      // The type comes from shared-mime-info, the name is the short family name.
      expect(find.text('Text'), findsWidgets);
      expect(find.text('Testo semplice'), findsNothing);
    },
  );
}
