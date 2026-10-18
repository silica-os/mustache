import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/info.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/preview_pane.dart';

import 'kit.dart';

void main() {
  testWidgets('pane: geometry of the kit Preview Pane master', (tester) async {
    final entry = Entry(
      name: 'Alfa',
      path: '/prova/Alfa',
      isDirectory: true,
      size: 0,
      modified: DateTime(2026, 10, 14, 16, 1),
    );
    final added = <String>[];
    Offset? more;
    await tester.pumpWidget(
      kitScene(
        SizedBox(
          width: 260,
          height: 588,
          child: PreviewPane(
            items: [entry],
            kindOf: (_) => 'Folder',
            now: DateTime(2026, 10, 14, 18),
            tagsOf: (_) => const [],
            onAddTag: (_, tag) => added.add(tag),
            actions: [PaneAction('More', 'ellipsis-circle', (at) => more = at)],
          ),
        ),
      ),
    );
    final pane = tester.getRect(find.byKey(const ValueKey('preview pane')));
    Rect inPane(Finder f) => tester.getRect(f).shift(-pane.topLeft);
    // Kit `Apps/Mustache/Preview Pane` (260 × 588), frames from the master.
    final kit = loadKit('Preview Pane');
    expect(pane.size, kit.size);
    expect(inPane(find.text('Alfa')).top, kit.rect('Name').top);
    expect(inPane(find.text('Folder')).top, kit.rect('Kind').top);
    expect(inPane(find.text('Information')).top, kit.rect('Information').top);
    expect(inPane(find.text('Created')).top, kit.rect('Created').top);
    expect(inPane(find.text('Modified')).top, kit.rect('Modified').top);
    final field = kit.rect('Tags');
    final typed = inPane(find.byType(EditableText));
    expect(typed.top, greaterThanOrEqualTo(field.top));
    expect(typed.bottom, lessThanOrEqualTo(field.bottom));
    final bar = inPane(find.byKey(const ValueKey('pane actions')));
    expect(bar.top, kit.rects('Separator').last.top);
    expect(bar.bottom, kit.size.height);
    final button = inPane(find.byKey(const ValueKey('action More')));
    expect(button.topLeft, kit.rect('More').topLeft);
    expect(button.height, kit.rect('More').height);
    // The value of a row sits on the right edge, 16 from it.
    expect(inPane(find.text('Today, 16:01')).right, 244);
    // The tags field: Return adds.
    await tester.tap(find.text('Add a tag…'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Lavoro');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(added, ['Lavoro']);
    await tester.tap(find.byKey(const ValueKey('action More')));
    expect(more, isNotNull);
  });

  for (final info in [false, true]) {
    testWidgets('tags come off from ${info ? 'Get Info' : 'the pane'}', (
      tester,
    ) async {
      final entry = Entry(
        name: 'Alfa',
        path: '/prova/Alfa',
        isDirectory: true,
        size: 0,
        modified: DateTime(2026, 10, 14, 16, 1),
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<String>? left;
      await tester.pumpWidget(
        kitScene(
          info
              ? InfoPanel(
                  entry: entry,
                  kind: 'Folder',
                  open: const {InfoSection.general},
                  onToggle: (_) {},
                  onClose: () {},
                  onRename: (_) {},
                  tags: const ['Orange'],
                  onAddTag: (_) {},
                  onTagsChanged: (t) => left = t,
                )
              : SizedBox(
                  width: 260,
                  height: 588,
                  child: PreviewPane(
                    items: [entry],
                    kindOf: (_) => 'Folder',
                    now: DateTime(2026, 10, 14, 18),
                    tagsOf: (_) => const ['Orange'],
                    onAddTag: (_, tag) {},
                    onTagsChanged: (_, t) => left = t,
                    actions: const [],
                  ),
                ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(left, isEmpty);
    });
  }
}
