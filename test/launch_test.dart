import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/desktop.dart';
import 'package:mustache/src/go_to_folder.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/recents.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory home;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    home = Directory.systemTemp.createTempSync('mustache-launch');
    File('${home.path}/nota.txt').writeAsStringSync('ciao');
  });

  tearDown(() => home.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester, LaunchAction launch) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: home.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place(
            'Trash',
            '${home.path}/.local/share/Trash/files',
            PlaceKind.trash,
          ),
          settings: Settings('${home.path}/.config/s.json'),
          iconsEnv: {'HOME': home.path, 'XDG_DATA_HOME': '${home.path}/share'},
          launch: launch,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  test('--find and --go-to-folder are read from the arguments', () {
    expect(launchActionOf(['--find']), LaunchAction.find);
    expect(launchActionOf(['/a', '--go-to-folder']), LaunchAction.goToFolder);
    expect(launchActionOf(['--recents']), LaunchAction.recents);
    expect(launchActionOf(['/a']), LaunchAction.none);
  });

  test('the recently used list: newest first, files only, escapes undone', () {
    final list = parseRecentlyUsed('''
<bookmark href="file:///a/b%20c.txt" visited="2026-01-01T00:00:00Z"/>
<bookmark href="https://example.org/x" visited="2026-09-01T00:00:00Z"/>
<bookmark href="file:///z" visited="2026-02-01T00:00:00Z"></bookmark>
<bookmark href="file:///a/b%20c.txt" visited="2025-01-01T00:00:00Z"/>''');
    expect([for (final r in list) r.path], ['/z', '/a/b c.txt']);
    expect(parseRecentlyUsed('', limit: 1), isEmpty);
  });

  testWidgets('--find opens the window with the search field focused', (
    tester,
  ) async {
    await pump(tester, LaunchAction.find);
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.focusNode.hasFocus, isTrue);
    expect(find.byType(GoToFolderSheet), findsNothing);
  });

  testWidgets('--go-to-folder opens the window with the Go to Folder sheet', (
    tester,
  ) async {
    await pump(tester, LaunchAction.goToFolder);
    expect(find.byType(GoToFolderSheet), findsOneWidget);
  });

  testWidgets('--recents lists the recently used files that still exist', (
    tester,
  ) async {
    Directory('${home.path}/share').createSync();
    File('${home.path}/Zebra file.txt').writeAsStringSync('z');
    File('${home.path}/share/recently-used.xbel').writeAsStringSync('''
<?xml version="1.0"?>
<xbel version="1.0">
  <bookmark href="file://${home.path}/nota.txt" added="2026-01-01T00:00:00Z" modified="2026-01-01T00:00:00Z" visited="2026-01-02T00:00:00Z"/>
  <bookmark href="file://${home.path}/Zebra%20file.txt" added="2026-01-01T00:00:00Z" modified="2026-01-01T00:00:00Z" visited="2026-02-02T00:00:00Z"/>
  <bookmark href="file://${home.path}/gone.txt" visited="2026-03-01T00:00:00Z"/>
</xbel>''');
    await pump(tester, LaunchAction.recents);
    expect(find.text('Zebra file.txt'), findsOneWidget);
    expect(find.text('nota.txt'), findsOneWidget);
    expect(find.text('gone.txt'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Zebra file.txt')).dx,
      lessThan(tester.getTopLeft(find.text('nota.txt')).dx),
    );
  });

  testWidgets('without a launch action the window just opens', (tester) async {
    await pump(tester, LaunchAction.none);
    expect(find.byType(GoToFolderSheet), findsNothing);
    expect(find.text('nota.txt'), findsWidgets);
  });
}
