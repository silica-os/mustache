import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/gallery_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  paneToggleTests();
  testWidgets('⌘4: gallery with the strip and the pane; → advances', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-galleria');
    addTearDown(() => home.deleteSync(recursive: true));
    for (var i = 1; i <= 4; i++) {
      File('${home.path}/f$i.txt').writeAsStringSync('$i');
    }
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings('${home.path}/.s.json')..view = 'list';
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
    await tester.tap(find.text('f1.txt'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byType(GalleryView), findsOneWidget);
    expect(settings.view, 'gallery');
    expect(
      tester.getSize(find.byKey(const ValueKey('preview pane'))).width,
      260,
    );
    GalleryView gallery() =>
        tester.widget<GalleryView>(find.byType(GalleryView));
    expect(gallery().selected, '${home.path}/f1.txt');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(gallery().selected, '${home.path}/f2.txt');
    // Click on a thumbnail.
    await tester.tap(find.byKey(ValueKey('thumbnail ${home.path}/f4.txt')));
    await tester.pump(const Duration(milliseconds: 310));
    expect(gallery().selected, '${home.path}/f4.txt');
    final thumbs = tester.getRect(
      find.byKey(const ValueKey('thumbnail strip')),
    );
    expect(thumbs.height, galleryStrip + galleryBottom);
  });

  testWidgets(
    'without a choice the gallery chooses the first; the icon fills the preview',
    (tester) async {
      final home = Directory.systemTemp.createTempSync('mustache-galleria');
      addTearDown(() => home.deleteSync(recursive: true));
      Directory('${home.path}/Alfa').createSync();
      File('${home.path}/b.txt').writeAsStringSync('b');
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings('${home.path}/.s.json')..view = 'gallery';
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
      // The pane describes the chosen folder (MU-23).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('preview pane')),
          matching: find.text('Alfa'),
        ),
        findsOneWidget,
      );
      // The large icon is as big as the short side of the preview (not a fixed 256).
      final big = tester.getSize(find.byKey(const ValueKey('large preview')));
      expect(big.shortestSide, greaterThan(400));
    },
  );
}

void paneToggleTests() {
  testWidgets('Show/Hide Preview toggles the gallery pane and is remembered', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-galleria');
    addTearDown(() => home.deleteSync(recursive: true));
    File('${home.path}/a.txt').writeAsStringSync('a');
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final path = '${home.path}/.s.json';
    final settings = Settings(path)..view = 'gallery';
    Future<void> open() async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            key: UniqueKey(),
            start: home.path,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
            settings: Settings(path),
          ),
        ),
      );
      await tester.pump();
    }

    await open();
    final pane = find.byKey(const ValueKey('preview pane'));
    expect(pane, findsOneWidget);
    expect(settings.galleryPane, isNull);
    Future<void> combo() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
    }

    await combo();
    expect(pane, findsNothing);
    expect(Settings(path).galleryPane, isFalse);
    // A new window keeps it hidden; showing it again works.
    await open();
    expect(pane, findsNothing);
    await combo();
    expect(pane, findsOneWidget);
    expect(Settings(path).galleryPane, isTrue);
    // The full-height divider runs from the top of the window, over the bar.
    final line = tester.getRect(find.byKey(const ValueKey('preview divider')));
    expect(line.top, 0);
    expect(line.bottom, 800);
    expect(line.width, 1);
  });
}
