import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/emoji_data.dart';
import 'package:mustache/src/folder_customize.dart';
import 'package:mustache/src/folder_icons.dart';
import 'package:mustache/src/folder_style.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/tags.dart';
import 'package:mustache/src/window.dart';
import 'package:mustache/src/xattr.dart';
import 'package:silica_ui/silica_ui.dart';

import 'folder_fixture.dart';
import 'folder_style_test.dart' show FakeDisk, FakeMetadata, homeTemp;

const String _path = '/home/a/Lavoro';

void main() {
  late Directory icons;
  late Map<String, String> env;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    icons = folderIconsRoot();
    env = {'SILICA_ICONS_DIR': icons.path, 'HOME': '/nonexistent-home'};
    frequentEmoji
      ..clear()
      ..addAll(defaultFrequentEmoji);
  });

  tearDown(() => icons.deleteSync(recursive: true));

  late FakeDisk disk;
  late FolderStyles styles;
  var closed = 0;
  var editTags = 0;
  var writes = <List<String>>[];

  /// The popover over a 1000 x 800 area, pointing at a folder icon at (100, 100).
  Future<void> pumpPopover(
    WidgetTester tester, {
    bool fails = false,
    Brightness brightness = Brightness.dark,
  }) async {
    disk = FakeDisk();
    styles = FolderStyles(
      readAttribute: disk.read,
      writeAttribute: fails ? (_, _, _) => AttributeWrite.failed : disk.write,
      readTags: (path) => disk.tags[path] ?? const [],
      metadata: FakeMetadata(),
    );
    addTearDown(styles.dispose);
    closed = 0;
    editTags = 0;
    writes = [];
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(1000, 800),
            platformBrightness: brightness,
          ),
          // The window has an Overlay (the "+" menu is shown in it).
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (_) => Stack(
                  children: [
                    Positioned(
                      left: 100,
                      top: 100,
                      width: 64,
                      height: 64,
                      child: FolderIconAnchor(
                        path: _path,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned.fill(
                      child: FolderCustomizeOverlay(
                        path: _path,
                        env: env,
                        styles: styles,
                        writeTags: (path, tags) {
                          writes.add(tags);
                          disk.tags[path] = tags;
                          return true;
                        },
                        onEditTags: () => editTags++,
                        onClose: () => closed++,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// The body of the popover: its rectangle without the 8 pt arrow on the left.
  Rect body(WidgetTester tester) {
    final r = tester.getRect(find.byKey(const ValueKey('folder popover')));
    return Rect.fromLTRB(r.left + 8, r.top, r.right, r.bottom);
  }

  /// The left edge of a disc relative to the popover body.
  double discX(WidgetTester tester, String name) =>
      tester.getTopLeft(find.byKey(ValueKey('folder disc $name'))).dx -
      body(tester).left;

  Future<void> slide(WidgetTester tester, [int ms = 600]) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the popover: 320 x 460 body, arrow on the left of the icon', (
    tester,
  ) async {
    await pumpPopover(tester);
    final rect = body(tester);
    expect(rect.size, const Size(320, 460));
    // To the right of the icon (64 pt wide at x 100), the arrow pointing at it.
    expect(rect.left, greaterThan(164));
    // Preview 96 pt, discs 26 pt at a 34 pitch from x 46, the "+" 28 pt.
    expect(
      tester.getSize(find.byKey(const ValueKey('folder preview'))),
      const Size(96, 96),
    );
    expect(discX(tester, 'red'), 46);
    expect(discX(tester, 'orange'), 80);
    expect(discX(tester, 'gray'), 46 + 34 * 6);
    expect(
      tester.getSize(find.byKey(const ValueKey('folder disc red'))),
      const Size(26, 26),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('folder add tag'))),
      const Size(28, 28),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('folder emoji button'))),
      const Size(144, 28),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('folder clear'))),
      const Size(144, 28),
    );
    // The grid: 6 columns of 44 pt cells.
    final a = tester.getTopLeft(
      find.byKey(const ValueKey('folder symbol music-list')),
    );
    final b = tester.getTopLeft(
      find.byKey(const ValueKey('folder symbol music-note')),
    );
    expect(b.dx - a.dx, greaterThanOrEqualTo(44));
    expect(find.text('Customize Folder'), findsNothing);
  });

  testWidgets('the disc colours: dark and light', (tester) async {
    // The Amalfi palette: Terracotta, Accent/Amalfi (blue) and the neutral for gray.
    expect(folderDiscColor(TagColor.red, dark: true), const Color(0xFFFF6A43));
    expect(folderDiscColor(TagColor.red, dark: false), const Color(0xFFF0562E));
    expect(folderDiscColor(TagColor.blue, dark: true), const Color(0xFF3D95FF));
    expect(
      folderDiscColor(TagColor.gray, dark: false),
      AmalfiColors.light.textTertiary,
    );
    await pumpPopover(tester);
    Color? colour(String n) =>
        ((tester
                            .widget<Semantics>(
                              find.descendant(
                                of: find.byKey(ValueKey('folder disc $n')),
                                matching: find.byType(Semantics),
                              ),
                            )
                            .child!
                        as Container)
                    .decoration!
                as BoxDecoration)
            .color;
    expect(colour('purple'), AmalfiColors.dark.paletteLavanda);
    await pumpPopover(tester, brightness: Brightness.light);
    expect(colour('purple'), AmalfiColors.light.paletteLavanda);
  });

  testWidgets('a colour assigns its tag, tints the folder, joins the group', (
    tester,
  ) async {
    await pumpPopover(tester);
    expect(styles.look(_path).tint, isNull);
    await tester.tap(find.byKey(const ValueKey('folder disc red')));
    await tester.pump();
    expect(disk.tags[_path], ['Red']);
    expect(styles.look(_path).tint, 'red');
    // The preview is tinted at once, with no fade: the very next frame.
    final preview = tester.widget<SilicaIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('folder preview')),
        matching: find.byWidgetPredicate(
          (w) => w is SilicaIcon && w.source is ServiceSource,
        ),
      ),
    );
    expect('${(preview.source as ServiceSource).revision}', startsWith('red|'));
    // The check, the divider and the other discs sliding ~8 pt right (~280 ms).
    expect(find.text('✓'), findsOneWidget);
    expect(find.byKey(const ValueKey('folder tag divider')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    expect(discX(tester, 'orange'), lessThan(88));
    await slide(tester);
    expect(discX(tester, 'red'), 46);
    expect(discX(tester, 'orange'), 88);
    expect(discX(tester, 'gray'), 88 + 34 * 5);
    final divider = tester.getRect(
      find.byKey(const ValueKey('folder tag divider')),
    );
    expect(divider.width, 2);
    expect(divider.left - body(tester).left, 46 + 26 + 6);

    // A second tag: the group is 36 wide, the newest in front, on the left; the folder takes
    // the colour of the last assigned.
    await tester.tap(find.byKey(const ValueKey('folder disc orange')));
    await slide(tester);
    expect(disk.tags[_path], ['Red', 'Orange']);
    expect(styles.look(_path).tint, 'orange');
    expect(discX(tester, 'orange'), 46);
    expect(discX(tester, 'red'), 56);
    expect(discX(tester, 'yellow'), 46 + 36 + 6 + 2 + 8);
    // In front: orange paints after red.
    final order = [
      for (final w in tester.widgetList(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key! as ValueKey).value}'.startsWith('folder disc '),
        ),
      ))
        '${(w.key! as ValueKey).value}',
    ];
    expect(
      order.indexOf('folder disc orange'),
      greaterThan(order.indexOf('folder disc red')),
    );

    // Clicking the assigned disc removes the tag (the folder goes back to red).
    await tester.tap(find.byKey(const ValueKey('folder disc orange')));
    await slide(tester);
    expect(disk.tags[_path], ['Red']);
    expect(styles.look(_path).tint, 'red');
  });

  testWidgets('hover: a white plus and the tag name; × on an assigned one', (
    tester,
  ) async {
    await pumpPopover(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(1, 1));
    expect(find.byKey(const ValueKey('folder caption')), findsNothing);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('folder disc green'))),
    );
    await tester.pump();
    expect(find.text('+'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('folder caption'))).data,
      'Green',
    );
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('+'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('folder disc green')));
    await slide(tester);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('folder disc green'))),
    );
    await tester.pump();
    expect(find.text('×'), findsOneWidget);
    expect(find.text('✓'), findsNothing);
  });

  testWidgets('remove all tags: back to blue, the row slides back in ~470 ms', (
    tester,
  ) async {
    await pumpPopover(tester);
    disk.tags[_path] = ['Red', 'Verde', 'Progetti'];
    styles.invalidate([_path]);
    await tester.pump();
    await tester.pump();
    expect(styles.look(_path).tint, 'green');
    await slide(tester);
    expect(find.byKey(const ValueKey('folder tag divider')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('folder remove all tags')));
    await tester.pump();
    expect(disk.tags[_path], isEmpty);
    expect(styles.look(_path).tint, isNull);
    expect(find.byKey(const ValueKey('folder tag divider')), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(discX(tester, 'red'), isNot(46 + 0.0), reason: 'still sliding');
    await slide(tester, 700);
    for (var i = 0; i < TagColor.values.length; i++) {
      expect(discX(tester, TagColor.values[i].name), 46 + 34.0 * i);
    }
  });

  testWidgets('the remove all button does nothing without tags', (
    tester,
  ) async {
    await pumpPopover(tester);
    await tester.tap(find.byKey(const ValueKey('folder remove all tags')));
    await tester.pump();
    expect(writes, isEmpty);
  });

  testWidgets('a symbol is saved at once; Clear keeps the tags', (
    tester,
  ) async {
    await pumpPopover(tester);
    await tester.tap(find.byKey(const ValueKey('folder disc blue')));
    await tester.pump();
    // The seven categories in order (fixture: those with symbols), then Clear is disabled.
    expect(find.text('Objects'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('folder clear')));
    await tester.pump();
    expect(styles.stored(_path), isNull);

    await tester.tap(find.byKey(const ValueKey('folder symbol music-note')));
    await tester.pump();
    expect(styles.stored(_path), const FolderStyle(symbol: 'music-note'));
    expect(
      disk.attributes[_path]?[folderStyleAttribute],
      '{"symbol":"music-note"}',
    );
    expect(styles.look(_path).symbol, 'music-note');
    // The selection: a 2 pt accent ring.
    final ring = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('folder symbol music-note')),
        matching: find.byType(Container),
      ),
    );
    final border = (ring.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 2);
    expect(border.top.color, AmalfiColors.dark.accentAmalfi);

    await tester.tap(find.byKey(const ValueKey('folder clear')));
    await tester.pump();
    expect(styles.stored(_path), isNull);
    expect(disk.tags[_path], ['Blue'], reason: 'the tags stay');
    expect(styles.look(_path).tint, 'blue');
  });

  testWidgets('the symbols are in categories, Objects first as in the kit', (
    tester,
  ) async {
    final categories = folderSymbolCategories(env: env);
    expect(
      [for (final c in categories) c.id],
      [
        SymbolCategoryId.objects,
        SymbolCategoryId.people,
        SymbolCategoryId.activities,
      ],
    );
    // The kit's first rows come first, then the rest of the category.
    expect(categories.first.names, ['star', 'house', 'music-note', 'doc-text']);
    expect(categories.last.names, ['music-list']);
    expect(SymbolCategoryId.values, hasLength(7));
    // Every symbol is in exactly one category.
    final all = [for (final c in categories) ...c.names];
    expect(all.toSet(), fixtureSymbols.toSet());
    expect(all, hasLength(fixtureSymbols.length));
  });

  testWidgets('the emoji picker: search, pick, drawn in colour, replaces the '
      'symbol', (tester) async {
    await pumpPopover(tester);
    await tester.tap(find.byKey(const ValueKey('folder symbol star')));
    await tester.pump();
    expect(find.byKey(const ValueKey('emoji popover')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('folder emoji button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('emoji popover')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('emoji popover'))),
      const Size(320, 304),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('emoji search'))).height,
      28,
    );
    // Frequently used first, and a category bar.
    expect(find.text('Frequently Used'), findsOneWidget);
    expect(find.byKey(const ValueKey('emoji category 8')), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('emoji search')),
        matching: find.byType(EditableText),
      ),
      'guitar',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('emoji 🎸')), findsOneWidget);
    expect(find.byKey(const ValueKey('emoji 🎵')), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('emoji search')),
        matching: find.byType(EditableText),
      ),
      'zzzz',
    );
    await tester.pump();
    expect(find.text('No emoji found'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('emoji search')),
        matching: find.byType(EditableText),
      ),
      '',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('emoji 🎵')).first);
    await tester.pump();
    expect(find.byKey(const ValueKey('emoji popover')), findsNothing);
    expect(styles.stored(_path), const FolderStyle(emoji: '🎵'));
    expect(disk.attributes[_path]?[folderStyleAttribute], '{"emoji":"🎵"}');
    expect(frequentEmoji.first, '🎵');
    // Drawn on the preview at about a third of the icon, replacing the symbol.
    final emoji = find.descendant(
      of: find.byKey(const ValueKey('folder preview')),
      matching: find.byKey(const ValueKey('folder emoji')),
    );
    expect(emoji, findsOneWidget);
    expect(
      tester
          .getSize(find.ancestor(of: emoji, matching: find.byType(FittedBox)))
          .width,
      closeTo(96 * folderEmojiRatio, 0.01),
    );
    expect(styles.look(_path).symbol, isNull);
    // The Emoji button shows it, and Clear removes it.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('folder emoji button')),
        matching: find.text('🎵'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('folder clear')));
    await tester.pump();
    expect(styles.stored(_path), isNull);
    expect(emoji, findsNothing);
  });

  testWidgets('the "+" menu: colourless tags and Edit Tags…', (tester) async {
    await pumpPopover(tester);
    disk.tags[_path] = ['Progetti', 'Red'];
    styles.invalidate([_path]);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('folder add tag')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Progetti'), findsOneWidget);
    expect(find.text('Edit Tags…'), findsOneWidget);
    await tester.tap(find.text('Progetti'));
    await slide(tester, 1000);
    expect(find.byType(AmalfiMenu), findsNothing, reason: 'the menu closed');
    expect(disk.tags[_path], ['Red']);
    await tester.tap(find.byKey(const ValueKey('folder add tag')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Progetti'), findsNothing);
    await tester.tap(find.text('Edit Tags…'));
    await slide(tester, 1000);
    expect(editTags, 1);
  });

  testWidgets('Esc closes and keeps the changes; Esc first closes the emoji '
      'picker; a click outside closes', (tester) async {
    await pumpPopover(tester);
    await tester.tap(find.byKey(const ValueKey('folder disc purple')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('folder emoji button')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('emoji popover')), findsNothing);
    expect(closed, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closed, 1);
    expect(disk.tags[_path], ['Purple'], reason: 'the changes stay');

    await tester.tapAt(const Offset(20, 700));
    await tester.pump();
    expect(closed, 2);
  });

  testWidgets('a folder that cannot be changed says so', (tester) async {
    await pumpPopover(tester, fails: true);
    await tester.tap(find.byKey(const ValueKey('folder symbol star')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('folder caption'))).data,
      "This folder can't be customized.",
    );
    expect(styles.stored(_path), isNull);
  });

  testWidgets('a change made elsewhere shows in the open popover', (
    tester,
  ) async {
    await pumpPopover(tester);
    disk.write(_path, folderStyleAttribute, '{"symbol":"house"}');
    styles.changed(_path);
    await tester.pump(const Duration(milliseconds: 200));
    final ring = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('folder symbol house')),
        matching: find.byType(Container),
      ),
    );
    expect((ring.decoration! as BoxDecoration).border, isNotNull);
  });

  testWidgets('the tag dots: the last assigned in front, 6 pt in icon view', (
    tester,
  ) async {
    Future<List<double>> lefts(double? pitch) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: pitch == null
              ? const Align(
                  alignment: Alignment.topLeft,
                  child: TagDots(tags: ['Red', 'Orange']),
                )
              : Align(
                  alignment: Alignment.topLeft,
                  child: TagDots(tags: const ['Red', 'Orange'], pitch: pitch),
                ),
        ),
      );
      return [
        for (final p in tester.widgetList<Positioned>(find.byType(Positioned)))
          p.left!,
      ];
    }

    // Painted from the back: the first assigned (Red) behind, at the offset.
    expect(await lefts(null), [5, 0]);
    expect(await lefts(iconTagPitch), [6, 0]);
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(TagDots),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      16,
    );
    final colours = [
      for (final d in tester.widgetList<Container>(
        find.descendant(
          of: find.byType(TagDot),
          matching: find.byType(Container),
        ),
      ))
        (d.decoration! as BoxDecoration).color,
    ];
    expect(colours.last, menuTagColor(TagColor.orange), reason: 'in front');
  });

  group('in the window', () {
    late Directory home;
    late Directory folder;

    Future<bool> pumpWindow(
      WidgetTester tester, {
      bool customize = false,
    }) async {
      home = homeTemp('mustache-folder-menu');
      folder = Directory('${home.path}/Doc/Progetti')
        ..createSync(recursive: true);
      File('${home.path}/Doc/nota.txt').writeAsStringSync('x');
      if (!writeTags(folder.path, [])) return false;
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: '${home.path}/Doc',
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
            settings: Settings('${home.path}/s.json')..view = 'list',
            iconsEnv: {...env, 'HOME': home.path},
            customize: customize ? folder.path : null,
          ),
        ),
      );
      return true;
    }

    Future<void> rightClickFolder(WidgetTester tester) async {
      final row = find.descendant(
        of: find.byType(ListView),
        matching: find.text('Progetti'),
      );
      await tester.tapAt(tester.getCenter(row), buttons: kSecondaryMouseButton);
      await tester.pump();
    }

    ({String? tint, String? symbol})? drawnFolder(WidgetTester tester) {
      for (final icon in tester.widgetList<SilicaIcon>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byWidgetPredicate(
            (w) => w is SilicaIcon && w.source is ServiceSource,
          ),
        ),
      )) {
        if (icon.source case ServiceSource(:final revision)) {
          final parts = '$revision'.split('|');
          String? part(int i) => parts[i] == 'null' ? null : parts[i];
          return (tint: part(0), symbol: part(1));
        }
      }
      return null;
    }

    testWidgets('the colour dots tag a folder and tint it', (tester) async {
      if (!await pumpWindow(tester)) {
        markTestSkipped('no extended attributes on this file system');
        return;
      }
      expect(drawnFolder(tester)?.tint, isNull);
      await rightClickFolder(tester);
      // The Tags submenu: one item per color.
      await tester.tap(find.text('Tags…'));
      await tester.pump(const Duration(milliseconds: 400));
      for (final c in [
        'Red',
        'Orange',
        'Yellow',
        'Green',
        'Blue',
        'Purple',
        'Gray',
      ]) {
        expect(
          find.descendant(of: find.byType(AmalfiMenu), matching: find.text(c)),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.descendant(
          of: find.byType(AmalfiMenu),
          matching: find.text('Orange'),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(readTags(folder.path), ['Orange']);
      expect(folderStyles.look(folder.path).tint, 'orange');
      expect(drawnFolder(tester)?.tint, 'orange');
      writeTags(folder.path, []);
      folderStyles.invalidate([folder.path]);
    });

    testWidgets('Customize Folder… opens the popover on the folder icon', (
      tester,
    ) async {
      if (!await pumpWindow(tester)) {
        markTestSkipped('no extended attributes on this file system');
        return;
      }
      await rightClickFolder(tester);
      await tester.tap(find.text('Customize Folder…'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byType(AmalfiMenu), findsNothing, reason: 'the menu closed');
      // A popover, not a Get Info window.
      expect(find.byKey(ValueKey('info ${folder.path}')), findsNothing);
      expect(find.byKey(const ValueKey('folder popover')), findsOneWidget);
      // It points at the folder's icon: to its right, level with it.
      final icon = tester.getRect(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byWidgetPredicate(
                (w) => w is SilicaIcon && w.source is ServiceSource,
              ),
            )
            .first,
      );
      final rect = tester.getRect(find.byKey(const ValueKey('folder popover')));
      expect(rect.left, greaterThanOrEqualTo(icon.right));
      await tester.tap(find.byKey(const ValueKey('folder symbol star')));
      await tester.pump();
      expect(
        readAttribute(folder.path, folderStyleAttribute),
        '{"symbol":"star"}',
      );
      expect(drawnFolder(tester)?.symbol, 'star');

      // A colour is a tag, and the window's tag cache follows.
      await tester.tap(find.byKey(const ValueKey('folder disc green')));
      await tester.pump();
      expect(readTags(folder.path), ['Green']);
      expect(drawnFolder(tester)?.tint, isNotNull);

      // Changed by another app: the watcher's notice redraws the icon.
      writeAttribute(folder.path, folderStyleAttribute, '{"symbol":"house"}');
      folderStyles.changed(folder.path);
      await tester.pump(const Duration(milliseconds: 200));
      expect(drawnFolder(tester)?.symbol, 'house');

      // Esc closes it and keeps the changes.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('folder popover')), findsNothing);
      expect(readTags(folder.path), ['Green']);
      writeTags(folder.path, []);
      folderStyles.save(folder.path, const FolderStyle());
    });

    testWidgets('started from the desktop, the popover opens on the folder', (
      tester,
    ) async {
      if (!await pumpWindow(tester, customize: true)) {
        markTestSkipped('no extended attributes on this file system');
        return;
      }
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byKey(ValueKey('info ${folder.path}')), findsNothing);
      expect(find.byKey(const ValueKey('folder popover')), findsOneWidget);
    });

    testWidgets('a file has Tags…, a folder also Customize Folder…', (
      tester,
    ) async {
      if (!await pumpWindow(tester)) {
        markTestSkipped('no extended attributes on this file system');
        return;
      }
      await tester.tapAt(
        tester.getCenter(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('nota.txt'),
          ),
        ),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      expect(find.text('Tags…'), findsOneWidget);
      expect(find.text('Customize Folder…'), findsNothing);
      await tester.tapAt(const Offset(5, 690));
      await tester.pump();
      await rightClickFolder(tester);
      expect(find.text('Customize Folder…'), findsOneWidget);
      expect(find.text('Tags…'), findsOneWidget);
    });
  });
}
