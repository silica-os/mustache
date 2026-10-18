import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/dialog.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  test('dialog arguments and URIs', () {
    final d = DialogOptions.parse([
      '--dialog=save',
      '--title=Esporta',
      '--name=relazione.pdf',
      '--folder=/',
    ])!;
    expect(d.save, isTrue);
    expect(d.title, 'Esporta');
    expect(d.name, 'relazione.pdf');
    expect(d.folder, '/');
    expect(d.acceptLabel, 'Save');
    expect(DialogOptions.parse(['/home']), isNull);
    expect(
      DialogOptions.parse([
        '--dialog=open',
        '--multiple',
        '--folder=/non/esiste',
      ])!.folder,
      isNull,
    );
    expect(fileUri('/home/io/a b.txt'), 'file:///home/io/a%20b.txt');
  });

  group('in the window', () {
    late Directory home;
    late List<List<String>> finished;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            GlassRegistry.channel,
            (call) async => true,
          );
      home = Directory.systemTemp.createTempSync('mustache-dialogo');
      File('${home.path}/nota.txt').writeAsStringSync('x');
      Directory('${home.path}/Cartella').createSync();
      finished = [];
    });

    tearDown(() => home.deleteSync(recursive: true));

    Future<void> pump(WidgetTester tester, DialogOptions dialog) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: home.path,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
            settings: Settings('${home.path}/.s.json')..view = 'list',
            dialog: dialog,
            onDialogFinish: finished.add,
          ),
        ),
      );
    }

    testWidgets(
      'the footer as the kit\'s Open panel: 12 pt under the divider, 20 pt from the sides and '
      'the bottom (mustache#30)',
      (tester) async {
        await pump(tester, const DialogOptions(save: false, title: 'Open'));
        final bar = tester.getRect(
          find.byKey(const ValueKey('dialog buttons')),
        );
        final divider = tester.getRect(
          find.byKey(const ValueKey('dialog divider')),
        );
        final cancel = tester.getRect(
          find.byKey(const ValueKey('dialog Cancel')),
        );
        final open = tester.getRect(find.byKey(const ValueKey('dialog Open')));
        // The bar is at the bottom of the window.
        expect(bar.bottom, 700);
        expect(divider.top, bar.top);
        expect(divider.height, 1);
        // The buttons: 12 below the divider, 20 above the bottom, 20 from the right, 8 apart.
        expect(cancel.top - divider.bottom, dialogFooterTop);
        expect(bar.bottom - cancel.bottom, dialogFooterBottom);
        expect(cancel.height, dialogButtonHeight);
        expect(open.top, cancel.top);
        expect(bar.right - open.right, dialogFooterSide);
        expect(open.left - cancel.right, dialogFooterGap);
      },
    );

    testWidgets('Open: double click on a file chooses it; Esc cancels', (
      tester,
    ) async {
      await pump(
        tester,
        const DialogOptions(save: false, title: 'Scegli un file'),
      );
      expect(find.text('Scegli un file'), findsOneWidget);
      await tester.tap(find.text('nota.txt'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('nota.txt'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(finished, [
        ['${home.path}/nota.txt'],
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(finished.last, isEmpty);
    });

    testWidgets('Save: the name in the open folder; replacing asks', (
      tester,
    ) async {
      await pump(tester, const DialogOptions(save: true, name: 'nuovo.txt'));
      await tester.tap(find.byKey(const ValueKey('dialog Save')));
      await tester.pump();
      expect(finished, [
        ['${home.path}/nuovo.txt'],
      ]);
      await tester.enterText(
        find.byKey(const ValueKey('dialog name field')),
        'nota.txt',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dialog Save')));
      await tester.pump();
      expect(find.byType(AmalfiAlert), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('alert Replace')));
      await tester.pump();
      expect(finished.last, ['${home.path}/nota.txt']);
    });

    testWidgets('folders: without a choice the open one counts', (
      tester,
    ) async {
      await pump(tester, const DialogOptions(save: false, directory: true));
      await tester.tap(find.byKey(const ValueKey('dialog Open')));
      await tester.pump();
      expect(finished, [
        [home.path],
      ]);
    });
  });
}
