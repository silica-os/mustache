import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/desktop.dart';
import 'package:mustache/src/go_to_folder.dart';
import 'package:mustache/src/model.dart';
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
          iconsEnv: {'HOME': home.path},
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
    expect(launchActionOf(['/a']), LaunchAction.none);
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

  testWidgets('without a launch action the window just opens', (tester) async {
    await pump(tester, LaunchAction.none);
    expect(find.byType(GoToFolderSheet), findsNothing);
    expect(find.text('nota.txt'), findsWidgets);
  });
}
