// The menus in Silica's menu bar (menus.dart, docs/spec/menus-and-settings.md): the model the app
// publishes on `silica/menu` for the window, the tabs, the dialog and the desktop, the choices that
// come back and the ⌘ shortcuts the bar binds.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/desktop.dart';
import 'package:mustache/src/dialog.dart';
import 'package:mustache/src/icon_arrange.dart';
import 'package:mustache/src/l10n.dart';
import 'package:mustache/src/menu_scope.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/tabs.dart';
import 'package:mustache/src/transfer.dart' show FileClipboard;
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart' show SilicaApp, SilicaMenuDelegate;

void main() {
  late Directory root;
  late List<MethodCall> calls;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-menus');
    Directory('${root.path}/Alfa').createSync();
    File('${root.path}/Alfa/dentro.txt').writeAsStringSync('ciao');
    File('${root.path}/nota.txt').writeAsStringSync('testo');
  });

  tearDown(() => root.deleteSync(recursive: true));

  List<Place> places() => [Place('casa', root.path, PlaceKind.home)];
  Place trash() => Place('Trash', '${root.path}/Cestino', PlaceKind.trash);

  Future<void> start(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    calls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SilicaMenuDelegate.defaultChannel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SilicaMenuDelegate.defaultChannel,
        null,
      ),
    );
    useLocale(const Locale('en'));
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: child),
    );
    await tester.pump();
    await tester.pump();
  }

  Widget window({
    DialogOptions? dialog,
    bool tabs = false,
    ViewMode view = ViewMode.list,
  }) {
    final settings = Settings(
      '${Directory.systemTemp.createTempSync('mustache-menus-settings').path}/s.json',
    )..view = view.name;
    Widget one(
      String start,
      Widget? bar,
      ValueChanged<String>? onLocation,
      bool active,
    ) => MustacheWindow(
      start: start,
      places: places(),
      trash: trash(),
      settings: settings,
      dialog: dialog,
      tabBar: bar,
      onLocation: onLocation,
      focused: active,
    );
    return MenuScope(
      child: tabs
          ? TabsHost(
              start: root.path,
              build: (tab, bar, onLocation, active) =>
                  one(tab.location, bar, onLocation, active),
            )
          : one(root.path, null, null, true),
    );
  }

  List<Map<Object?, Object?>> menus() =>
      ((calls.lastWhere((c) => c.method == 'setMenus').arguments
                  as Map)['menus']
              as List)
          .cast<Map<Object?, Object?>>();

  Iterable<Map<Object?, Object?>> items(String menu) =>
      (menus().firstWhere((m) => m['label'] == menu)['items'] as List)
          .cast<Map<Object?, Object?>>()
          .where((i) => i['separator'] != true);

  Map<Object?, Object?> item(String menu, String label) =>
      items(menu).firstWhere((i) => i['label'] == label);

  bool enabled(String menu, String label) =>
      item(menu, label)['enabled'] == true;

  Future<void> choose(WidgetTester tester, Map<Object?, Object?> item) async {
    expect(item['enabled'], isTrue, reason: '${item['label']}');
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SilicaMenuDelegate.defaultChannel.name,
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('activated', item['id']),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> command(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the menus in order; the app menu has no Quit', (tester) async {
    // As main() sets it for the file manager (DOCK-02).
    SilicaApp.quitEnabled = false;
    addTearDown(() => SilicaApp.quitEnabled = true);
    await start(tester, window());
    expect(menus().map((m) => m['label']), [
      'Mustache',
      'File',
      'Edit',
      'View',
      'Go',
      'Window',
      // The standard Help menu (silica-ui#99): the bar gives its title.
      '',
    ]);
    expect(menus().map((m) => m['role']), [
      'app',
      null,
      null,
      null,
      null,
      'window',
      'help',
    ]);
    final app = items('Mustache').map((i) => i['role'] ?? i['label']).toList();
    expect(app, [
      'about',
      'settings',
      'Empty Trash…',
      'services',
      'hide',
      'hide_others',
      'show_all',
    ]);
    // About opens the standard About panel (silica-ui#99); Settings and Empty Trash work.
    expect(item('Mustache', 'Empty Trash…')['enabled'], isTrue);
    expect(items('Mustache').first['enabled'], isTrue);
    expect(items('Mustache').first['id'], isA<int>());
    expect(item('Mustache', 'Empty Trash…')['shortcut'], {
      'key': 'Backspace',
      'meta': true,
      'shift': true,
    });
  });

  testWidgets(
    'App › Settings… opens the Settings (a sheet where Silica has no windows)',
    (tester) async {
      await start(tester, window());
      final settings = items(
        'Mustache',
      ).firstWhere((i) => i['role'] == 'settings');
      await choose(tester, settings);
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('settings sheet')), findsOneWidget);
      expect(find.text('Windows and names'), findsOneWidget);
      await tester.tap(find.text('Advanced'));
      await tester.pump();
      expect(find.text('Keep folders on top'), findsOneWidget);
      await tester.tapAt(const Offset(4, 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('settings sheet')), findsNothing);
    },
  );

  testWidgets('no selection: item actions are disabled, the rest runs', (
    tester,
  ) async {
    await start(tester, window());
    expect(item('File', 'New Mustache Window')['shortcut'], {
      'key': 'N',
      'meta': true,
    });
    expect(enabled('File', 'New Mustache Window'), isTrue);
    expect(enabled('File', 'New Folder'), isTrue);
    expect(enabled('File', 'Get Info'), isTrue);
    for (final label in [
      'Open',
      'Rename',
      'Duplicate',
      'Quick Look',
      'Move to Trash',
      'New Folder with Selection',
      'Compress',
      'Share…',
      'Print',
      'Eject',
    ]) {
      expect(enabled('File', label), isFalse, reason: label);
    }
    expect(enabled('File', 'Open With'), isFalse);
    // Edit: nothing to undo or paste; Copy needs a selection; Select All and Find work.
    expect(enabled('Edit', 'Undo'), isFalse);
    expect(enabled('Edit', 'Cut'), isFalse);
    expect(enabled('Edit', 'Copy'), isFalse);
    expect(enabled('Edit', 'Paste Item'), isFalse);
    expect(enabled('Edit', 'Select All'), isTrue);
    expect(enabled('Edit', 'Find'), isTrue);
    // View: the four views (the list is the one chosen), the bars, the disabled rest.
    expect(item('View', 'as List')['checked'], isTrue);
    expect(item('View', 'as Icons')['checked'], isNull);
    expect(item('View', 'as Gallery')['shortcut'], {'key': '4', 'meta': true});
    expect(item('View', 'Hide Sidebar')['shortcut'], {
      'key': 'S',
      'meta': true,
      'ctrl': true,
    });
    expect(enabled('View', 'Show Status Bar'), isTrue);
    expect(enabled('View', 'Hide Toolbar'), isFalse);
    expect(enabled('View', 'Show View Options'), isFalse);
    expect(enabled('View', 'Use Groups'), isFalse);
    expect(enabled('View', 'Clean Up'), isFalse);
    // Go: Back and Forward wait for a history.
    expect(enabled('Go', 'Back'), isFalse);
    expect(enabled('Go', 'Forward'), isFalse);
    expect(enabled('Go', 'Home'), isTrue);
    expect(enabled('Go', 'Recents'), isTrue);
    expect(enabled('Go', 'Recent Folders'), isFalse);
    // Window: the tab items wait for tabs.
    expect(enabled('Window', 'Show Next Tab'), isFalse);
  });

  testWidgets('a file or a folder selected changes the labels and Open With', (
    tester,
  ) async {
    await start(tester, window());
    await tester.tap(find.text('nota.txt'));
    await tester.pump();
    await tester.pump();
    expect(enabled('File', 'New Folder with “nota.txt”'), isFalse);
    expect(enabled('File', 'Open'), isTrue);
    expect(enabled('File', 'Rename'), isTrue);
    expect(enabled('File', 'Duplicate'), isTrue);
    expect(enabled('File', 'Move to Trash'), isTrue);
    expect(enabled('File', 'Quick Look'), isTrue);
    expect(enabled('File', 'Manage Shared File…'), isFalse);
    expect(enabled('Edit', 'Copy “nota.txt”'), isTrue);
    await tester.tap(find.text('Alfa'));
    await tester.pump();
    await tester.pump();
    expect(enabled('File', 'Open With'), isFalse);
    expect(enabled('File', 'Open'), isTrue);
    expect(enabled('File', 'Manage Shared Folder…'), isFalse);
    expect(enabled('Edit', 'Copy “Alfa”'), isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Edit › Cut, File › Make Link and Show Original', (tester) async {
    await start(tester, window());
    expect(enabled('File', 'Make Link'), isFalse);
    expect(enabled('File', 'Show Original'), isFalse);
    await tester.tap(find.text('nota.txt'));
    await tester.pump();
    await tester.pump();
    expect(enabled('Edit', 'Cut'), isTrue);
    expect(enabled('File', 'Show Original'), isFalse);
    await choose(tester, item('Edit', 'Cut'));
    expect(FileClipboard.cut, isTrue);
    expect(enabled('Edit', 'Paste Item'), isTrue);
    await choose(tester, item('File', 'Make Link'));
    expect(
      Link('${root.path}/nota link.txt').targetSync(),
      '${root.path}/nota.txt',
    );
    // The new link is selected: Show Original is available.
    expect(enabled('File', 'Show Original'), isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('App › Empty Trash… asks, then deletes what the Trash holds', (
    tester,
  ) async {
    Directory('${root.path}/files').createSync();
    Directory('${root.path}/info').createSync();
    File('${root.path}/files/old.txt').writeAsStringSync('x');
    File(
      '${root.path}/info/old.txt.trashinfo',
    ).writeAsStringSync('[Trash Info]');
    await start(tester, window());
    await choose(tester, item('Mustache', 'Empty Trash…'));
    expect(
      find.text(
        'Are you sure you want to permanently erase the items in the Trash?',
      ),
      findsOneWidget,
    );
    // Cancel keeps it.
    await tester.tap(find.byKey(const ValueKey('alert Cancel')));
    await tester.pump();
    await tester.pump();
    expect(File('${root.path}/files/old.txt').existsSync(), isTrue);
    await choose(tester, item('Mustache', 'Empty Trash…'));
    await tester.tap(find.byKey(const ValueKey('alert Empty Trash')));
    await tester.pump();
    expect(File('${root.path}/files/old.txt').existsSync(), isFalse);
    expect(File('${root.path}/info/old.txt.trashinfo').existsSync(), isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('choosing View, Select All, Copy and Paste from the bar', (
    tester,
  ) async {
    await start(tester, window());
    await choose(tester, item('View', 'as Icons'));
    expect(item('View', 'as Icons')['checked'], isTrue);
    expect(item('View', 'as List')['checked'], isNull);
    // Clean Up needs the free arrangement of the icon view; Sort By Name is chosen.
    expect(enabled('View', 'Clean Up By'), isTrue);
    await choose(tester, item('Edit', 'Select All'));
    expect(enabled('Edit', 'Copy 2 Items'), isTrue);
    await choose(tester, item('Edit', 'Copy 2 Items'));
    expect(enabled('Edit', 'Paste 2 Items'), isTrue);
    // Duplicate makes the copies next to the originals.
    await choose(tester, item('File', 'Duplicate'));
    expect(Directory('${root.path}/Alfa copy').existsSync(), isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the sidebar, the bars and the sort follow the window', (
    tester,
  ) async {
    await start(tester, window());
    await choose(tester, item('View', 'Hide Sidebar'));
    await tester.pump(const Duration(seconds: 1));
    expect(enabled('View', 'Show Sidebar'), isTrue);
    await choose(tester, item('View', 'Show Status Bar'));
    expect(enabled('View', 'Hide Status Bar'), isTrue);
    await choose(tester, item('View', 'Show Path Bar'));
    expect(enabled('View', 'Hide Path Bar'), isTrue);
    await choose(tester, item('View', 'Show Preview'));
    expect(enabled('View', 'Hide Preview'), isTrue);
    final sort = (item('View', 'Sort By')['items'] as List)
        .cast<Map<Object?, Object?>>()
        .where((i) => i['separator'] != true);
    Map<Object?, Object?> sortItem(String label) =>
        (item('View', 'Sort By')['items'] as List)
            .cast<Map<Object?, Object?>>()
            .firstWhere((i) => i['label'] == label);
    expect(sort.map((i) => i['label']), [
      'None',
      'Snap to Grid',
      'Name',
      'Type',
      'Last Opened',
      'Date Added',
      'Modified',
      'Created',
      'Size',
      'Tags',
    ]);
    expect(sortItem('Name')['checked'], isTrue);
    expect(sortItem('Last Opened')['enabled'], isFalse);
    expect(sortItem('None')['enabled'], isFalse);
    await choose(tester, sortItem('Size'));
    expect(sortItem('Size')['checked'], isTrue);
    expect(sortItem('Name')['checked'], isNull);
  });

  testWidgets('Go: places, enclosing folder, back and forward', (tester) async {
    await start(tester, window());
    expect(enabled('Go', 'Enclosing Folder'), isTrue);
    await choose(tester, item('Go', 'Enclosing Folder'));
    expect(enabled('Go', 'Back'), isTrue);
    await choose(tester, item('Go', 'Back'));
    expect(enabled('Go', 'Back'), isFalse);
    expect(enabled('Go', 'Forward'), isTrue);
    await choose(tester, item('Go', 'Forward'));
    expect(enabled('Go', 'Forward'), isFalse);
    expect(enabled('Go', 'Back'), isTrue);
  });

  testWidgets('⌘ shortcuts bound by the bar: ⌘A selects all', (tester) async {
    await start(tester, window());
    await command(tester, LogicalKeyboardKey.keyA);
    expect(enabled('Edit', 'Copy 2 Items'), isTrue);
  });

  testWidgets('Get Info and Find from the bar run', (tester) async {
    await start(tester, window());
    await choose(tester, item('Edit', 'Find'));
    // The search field has the keyboard: Edit acts on it.
    expect(items('Edit').map((i) => i['role']), contains('paste'));
    expect(items('Edit').map((i) => i['label']), contains('Find'));
  });

  testWidgets('tabs: one bar for the process, the active tab publishes', (
    tester,
  ) async {
    await start(tester, window(tabs: true));
    expect(enabled('File', 'New Tab'), isTrue);
    expect(enabled('File', 'Close Window'), isTrue);
    expect(enabled('Window', 'Show Next Tab'), isFalse);
    await choose(tester, item('File', 'New Tab'));
    expect(find.byKey(const ValueKey('tab bar')), findsOneWidget);
    expect(enabled('Window', 'Show Next Tab'), isTrue);
    expect(enabled('Window', 'Show Previous Tab'), isTrue);
    expect(tester.takeException(), isNull);
    // Close Window closes the tab; the other tab publishes again.
    await choose(tester, item('File', 'Close Window'));
    expect(find.byKey(const ValueKey('tab bar')), findsNothing);
    expect(enabled('Window', 'Show Next Tab'), isFalse);
    expect(enabled('File', 'New Tab'), isTrue);
  });

  testWidgets('the Open dialog: no new windows or Trash, Close cancels', (
    tester,
  ) async {
    await start(tester, window(dialog: const DialogOptions(save: false)));
    expect(enabled('File', 'New Mustache Window'), isFalse);
    expect(enabled('File', 'New Tab'), isFalse);
    expect(enabled('File', 'Get Info'), isFalse);
    expect(enabled('File', 'Close Window'), isTrue);
    expect(enabled('View', 'as Columns'), isTrue);
    expect(enabled('View', 'as Gallery'), isFalse);
    expect(item('View', 'as Columns')['checked'], isTrue);
    expect(enabled('View', 'Show Status Bar'), isFalse);
    expect(enabled('Go', 'Home'), isTrue);
  });

  group('the desktop', () {
    testWidgets('its own menus: stacks and sort enabled, windows disabled', (
      tester,
    ) async {
      final home = Directory.systemTemp.createTempSync('mustache-desktop');
      addTearDown(() => home.deleteSync(recursive: true));
      final folder = Directory('${home.path}/Desktop')..createSync();
      File('${folder.path}/uno.txt').writeAsStringSync('1');
      await start(
        tester,
        AppLocalizationsScope(
          locale: const Locale('en'),
          child: MenuScope(
            child: DesktopView(
              folder: folder.path,
              positions: IconPositions('${home.path}/positions.json'),
              choices: DesktopChoices('${home.path}/desktop.json'),
              env: {'HOME': home.path},
              kindOf: (e) => 'Text',
              watch: false,
              places: [Place('casa', home.path, PlaceKind.home)],
              readTags: (p) => const [],
              writeTags: (p, t) => true,
            ),
          ),
        ),
      );
      expect(menus().map((m) => m['label']), contains('Mustache'));
      for (final label in ['as Icons', 'as List', 'as Columns', 'as Gallery']) {
        expect(enabled('View', label), isFalse, reason: label);
      }
      expect(enabled('View', 'Use Stacks'), isTrue);
      expect(item('View', 'Use Stacks')['shortcut'], {
        'key': '0',
        'meta': true,
        'ctrl': true,
      });
      expect(enabled('View', 'Sort By'), isTrue);
      expect(enabled('View', 'Clean Up'), isFalse);
      expect(enabled('View', 'Hide Sidebar'), isFalse);
      expect(enabled('File', 'Close Window'), isFalse);
      expect(enabled('File', 'Open'), isFalse);
      expect(enabled('File', 'New Folder'), isTrue);
      expect(enabled('Edit', 'Select All'), isTrue);
      expect(enabled('Go', 'Back'), isFalse);
      // Use Stacks runs on the desktop.
      await choose(tester, item('View', 'Use Stacks'));
      expect(item('View', 'Use Stacks')['checked'], isTrue);
      // An icon selected: the file operations are enabled.
      await choose(tester, item('Edit', 'Select All'));
      expect(enabled('File', 'Open'), isTrue);
      expect(enabled('File', 'Duplicate'), isTrue);
      expect(enabled('File', 'Move to Trash'), isTrue);
    });
  });
}
