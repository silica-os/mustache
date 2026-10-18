import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/preview_pane.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/status_bar.dart';
import 'package:mustache/src/window.dart';

void main() {
  test('icon slider and bar text (spec/bars.md)', () {
    for (final (v, side) in [
      (0.0, 16.0),
      (8.0, 32.0),
      (24.0, 64.0),
      (56.0, 128.0),
      (64.0, 168.0),
      (80.0, 248.0),
      (112.0, 512.0),
    ]) {
      expect(iconSideFor(v), closeTo(side, 4.5), reason: 'value $v');
    }
    expect(sliderValueFor(64), closeTo(24, 0.01));
    expect(
      statusText(count: 12, selected: 0, free: 12345678901),
      '12 items, 12.35 GB available',
    );
    expect(
      statusText(count: 12, selected: 3, free: 1000000000),
      '3 of 12 selected, 1.00 GB available',
    );
    expect(statusText(count: 1, selected: 1, free: null), '1 of 1 selected');
    expect(
      statusText(count: 5, selected: 0, free: 10, listing: false),
      '5 items',
    );
  });

  testWidgets(
    '⌘\' shows the status bar, ⇧⌘P the pane; the slider changes the icons',
    (tester) async {
      final home = Directory.systemTemp.createTempSync('mustache-stato');
      addTearDown(() => home.deleteSync(recursive: true));
      File('${home.path}/a.txt').writeAsStringSync('ciao');
      File('${home.path}/b.txt').writeAsStringSync('x');
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings('${home.path}/.s.json')..view = 'icons';
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: home.path,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
            settings: settings,
          ),
        ),
      );
      Future<void> combo(
        LogicalKeyboardKey key, {
        bool shift = false,
        PhysicalKeyboardKey? physical,
      }) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(
          key,
          physicalKey: physical,
          platform: physical == null ? 'android' : 'linux',
        );
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pump();
      }

      // ⌘' is the apostrophe (`quoteSingle`): `quote` in Flutter is the " character. The test
      // simulator cannot produce the apostrophe: the binding is checked and its intent invoked.
      final shortcuts = tester
          .widgetList<Shortcuts>(find.byType(Shortcuts))
          .expand((s) => s.shortcuts.entries)
          .where(
            (e) =>
                e.key is SingleActivator &&
                (e.key as SingleActivator).trigger ==
                    LogicalKeyboardKey.quoteSingle &&
                (e.key as SingleActivator).meta,
          )
          .toList();
      expect(shortcuts, hasLength(1));
      Actions.invoke(
        tester.element(find.byType(IconView)),
        shortcuts.single.value,
      );
      await tester.pump();
      final bar = find.byKey(const ValueKey('status bar'));
      expect(bar, findsOneWidget);
      expect(tester.getSize(bar).height, statusBarHeight);
      expect(find.textContaining('2 items'), findsOneWidget);
      expect(settings.statusBar, isTrue);
      // The slider all the way right: 512 pt icons.
      final slider = find.byKey(const ValueKey('icon slider'));
      await tester.tapAt(
        tester.getRect(slider).centerRight - const Offset(1, 0),
      );
      await tester.pump();
      expect(
        tester.widget<IconView>(find.byType(IconView)).side,
        greaterThan(400),
      );
      expect(settings.iconSide, greaterThan(400));

      await combo(LogicalKeyboardKey.keyP, shift: true);
      final pane = find.byKey(const ValueKey('preview pane'));
      expect(pane, findsOneWidget);
      expect(tester.getSize(pane).width, previewPaneWidth);
    },
  );

  testWidgets(
    'a window built from settings.json without previewPane has no pane in icon view, also after '
    'the file was replaced while the app ran (mustache#29)',
    (tester) async {
      final home = Directory.systemTemp.createTempSync('mustache-pane');
      addTearDown(() => home.deleteSync(recursive: true));
      File('${home.path}/a.txt').writeAsStringSync('x');
      tester.view.physicalSize = const Size(1005, 679);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dir = Directory('${home.path}/.config/mustache')
        ..createSync(recursive: true);
      final path = '${dir.path}/settings.json';
      // An earlier session left the pane on; the app is running.
      File(path).writeAsStringSync('{"view":"icons","previewPane":true}');
      // (The watcher and its debounce run on real time.)
      final settings = (await tester.runAsync(
        () async => Settings(path)..watch(),
      ))!;
      addTearDown(settings.dispose);
      expect(settings.previewPane, isTrue);
      // The file is then replaced (temporary file renamed over it) with the one of the report.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        File('${dir.path}/settings.json.new')
          ..writeAsStringSync(
            '{"view":"icons","sidebarWidth":206.96484375,'
            '"infoSections":["general","name","comments","more"]}',
          )
          ..renameSync(path);
        for (var i = 0; i < 40 && settings.previewPane != null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      expect(settings.previewPane, isNull);
      // A fresh window: icon view, no pane, the search field in the main toolbar.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: home.path,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
            settings: settings,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(IconView), findsOneWidget);
      expect(find.byKey(const ValueKey('preview divider')), findsNothing);
      expect(find.byType(PreviewPane), findsNothing);
    },
  );
}
