import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

import 'kit.dart';

void main() {
  test(
    'the grid follows the kit Icons master: 104 tiles, 16 apart, 20 padding',
    () {
      final kit = loadKit('Icons');
      final first = kit.rect('Desktop');
      final second = kit.rect('Documents');
      final below = kit.rect('Public');
      // The content area of the master is 760 wide, from x 240, below the 52 pt toolbar.
      final g = iconGrid(760);
      expect(g.columns, 6);
      expect(g.pitchX, second.left - first.left);
      expect(g.pitchY, below.top - first.top);
      expect(g.tile, first.width);
      expect(g.top, first.top - 52);
      expect(g.centerX(0) - g.tile / 2, first.left - 240);
      // The icon size changes the tile (plus 40) and both pitches (plus 56).
      for (final side in [16.0, 32.0, 96.0, 128.0]) {
        final s = iconGrid(760, side: side);
        expect(s.pitchY, side + 56, reason: 'size $side');
        expect(s.tile, side + 40 < 104 ? 104 : side + 40, reason: 'size $side');
      }
      expect(iconGrid(760, side: 128).columns, 4);
      // Narrow content: one column at least.
      expect(iconGrid(100).columns, 1);
    },
  );

  testWidgets('label: at most two lines, the second truncated in the middle', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 12);
    expect(labelLines('breve.txt', 110, style), ['breve.txt']);
    final lines = labelLines(
      'un nome di file davvero molto lungo che non entra in due righe.pdf',
      110,
      style,
    );
    expect(lines, hasLength(2));
    expect(lines.last, contains('…'));
    expect(lines.last, endsWith('.pdf'));
    // A single word wider than the line wraps inside the word (in tests every character is as wide
    // as the text size: 9 per line).
    final word = labelLines('abcdefghijklmno', 110, style);
    expect(word, hasLength(2));
    expect(word.join(), 'abcdefghijklmno');
  });

  testWidgets('labels as in MU-21: wrapping at spaces, ~104 wide', (
    tester,
  ) async {
    const style = TextStyle(
      fontFamily: uiFontFamily,
      package: 'silica_ui',
      fontSize: 12,
    );
    final width = labelMaxWidth(12);
    List<String> lines(String name) => labelLines(name, width, style);
    expect(lines('senza estensione'), ['senza estensione']);
    expect(lines('barre colorate.mov'), ['barre', 'colorate.mov']);
    expect(lines('grande 4000x3000.png'), ['grande', '4000x3000.png']);
    expect(lines('strisce orizzontali.jpg'), ['strisce', 'orizzontali.jpg']);
    expect(lines('configurazione.json'), ['configurazione.js', 'on']);
    final beta = lines(
      'Beta con un nome molto lungo che non entra nella colonna',
    );
    expect(beta.first, 'Beta con un nome');
    expect(beta.last, startsWith('molto lu'));
    expect(beta.last, endsWith('…colonna'));
  });

  group('in the window', () {
    late Directory root;
    late Directory config;

    setUp(() {
      root = Directory.systemTemp.createTempSync('mustache-icone');
      config = Directory.systemTemp.createTempSync('mustache-config');
      for (final name in [
        'Alfa',
        'Beta',
        'Beta con un nome molto lungo che non entra nella colonna',
      ]) {
        Directory('${root.path}/$name').createSync();
      }
      // Enough files for two rows.
      for (var i = 0; i < 12; i++) {
        final name = 'file$i.txt';
        File('${root.path}/$name').writeAsStringSync('x');
      }
    });

    tearDown(() {
      root.deleteSync(recursive: true);
      config.deleteSync(recursive: true);
    });

    Future<Settings> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings('${config.path}/s.json');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: root.path,
            places: [Place('casa', root.path, PlaceKind.home)],
            trash: Place('Trash', '${root.path}/Cestino', PlaceKind.trash),
            settings: settings,
            // No silica-icons icon: the cells stay empty, the grid does not.
            iconsEnv: {'SILICA_ICONS_DIR': config.path},
          ),
        ),
      );
      return settings;
    }

    Finder label(String name) =>
        find.descendant(of: find.byType(IconView), matching: find.text(name));

    testWidgets('selection, name capsule, arrows in the grid', (tester) async {
      await pump(tester);
      // Natural order, folders and files together.
      expect(label('Alfa'), findsOneWidget);
      await tester.tap(label('Alfa'));
      await tester.pump();
      DecoratedBox capsule(String name) => tester.widget<DecoratedBox>(
        find.byKey(ValueKey('name ${root.path}/$name 0')),
      );
      final colors = AmalfiColors.light;
      expect(
        (capsule('Alfa').decoration as ShapeDecoration).color,
        colors.accentAmalfi,
      );
      expect(
        tester.widget<Text>(label('Alfa')).style?.color,
        colors.textOnAccent,
      );
      // → moves to the cell beside, ↓ to the row below (same column).
      final ordered = [
        for (final e in sortEntries(
          listDirectory(root.path, showHidden: false).entries,
          SortKey.name,
        ))
          e.name,
      ];
      final start = ordered.indexOf('Alfa');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        (capsule(ordered[start + 1]).decoration as ShapeDecoration).color,
        colors.accentAmalfi,
      );
      final columns = iconGrid(
        tester.getSize(find.byType(IconView)).width,
      ).columns;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final below = (start + 1 + columns).clamp(0, ordered.length - 1);
      expect(
        (capsule(ordered[below]).decoration as ShapeDecoration).color,
        colors.accentAmalfi,
      );
      // Click on the background: no selection.
      await tester.tapAt(
        tester.getBottomRight(find.byType(IconView)) - const Offset(20, 20),
      );
      await tester.pump();
      expect(
        (capsule(ordered[below]).decoration as ShapeDecoration).color,
        isNull,
      );
      // Lets the double-click wait expire.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('⌘2 switches to the list, ⌘1 to icons, and the choice stays', (
      tester,
    ) async {
      final settings = await pump(tester);
      expect(find.byType(IconView), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(find.byType(IconView), findsNothing);
      expect(find.text('Alfa'), findsOneWidget);
      expect(settings.view, 'list');
      expect(Settings(settings.path).view, 'list');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(find.byType(IconView), findsOneWidget);
    });

    testWidgets('the long label shows whole, tail included (MU-21)', (
      tester,
    ) async {
      await pump(tester);
      final second = find.textContaining('colonna');
      expect(second, findsOneWidget);
      final text = tester.widget<Text>(second);
      expect(text.data, startsWith('molto lu'));
      expect(text.softWrap, isFalse);
      // The row fits on a single line of text (16 pt).
      expect(tester.getSize(second).height, lessThanOrEqualTo(16));
    });
  });

  test('thumbnails only for images', () {
    expect(hasThumbnail('foto.JPG'), isTrue);
    expect(hasThumbnail('nota.txt'), isFalse);
    expect(hasThumbnail('.png'), isFalse);
  });
}
