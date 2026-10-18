import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/folder_icons.dart';

import 'package:silica_ui/silica_ui.dart';

void main() {
  test('a folder is full with one visible item; hidden files do not count', () {
    final dir = Directory.systemTemp.createTempSync('full-folder');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(folderHasItems(dir.path), isFalse);
    File('${dir.path}/.hidden').writeAsStringSync('');
    Directory('${dir.path}/.cache').createSync();
    expect(folderHasItems(dir.path), isFalse);
    File('${dir.path}/a.txt').writeAsStringSync('');
    expect(folderHasItems(dir.path), isTrue);
    // Gone or unreadable: empty, not an exception.
    expect(folderHasItems('${dir.path}/missing'), isFalse);
  });

  test('a folder that gains an item right after being asked is full', () {
    for (var i = 0; i < 20; i++) {
      final dir = Directory.systemTemp.createTempSync('full-folder');
      addTearDown(() => dir.deleteSync(recursive: true));
      expect(folderHasItems(dir.path), isFalse);
      File('${dir.path}/a.txt').writeAsStringSync('');
      expect(folderHasItems(dir.path), isTrue);
    }
  });

  test('the answer follows the folder when its contents change', () {
    final dir = Directory.systemTemp.createTempSync('full-folder');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/a.txt')..writeAsStringSync('');
    expect(folderHasItems(dir.path), isTrue);
    file.deleteSync();
    // Make the modification time differ even on a coarse clock.
    final later = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 5;
    Process.runSync('touch', ['-d', '@$later', dir.path]);
    expect(folderHasItems(dir.path), isFalse);
  });

  testWidgets('EntryIcon asks the system again when a folder gains an item', (
    tester,
  ) async {
    final tree = Directory.systemTemp.createTempSync('full-entries');
    addTearDown(() {
      tree.deleteSync(recursive: true);
    });
    Directory('${tree.path}/empty').createSync();
    Directory('${tree.path}/full').createSync();
    File('${tree.path}/full/a.txt').writeAsStringSync('');
    Directory('${tree.path}/hidden').createSync();
    File('${tree.path}/hidden/.a').writeAsStringSync('');
    Entry folder(String name) => Entry(
      name: name,
      path: '${tree.path}/$name',
      isDirectory: true,
      size: 0,
      modified: DateTime(2026),
    );

    Future<String> revision(String name) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: EntryIcon(entry: folder(name), side: 64),
        ),
      );
      final source = tester.widget<SilicaIcon>(find.byType(SilicaIcon)).source;
      expect((source as ServiceSource).isFolder, isTrue);
      return source.revision! as String;
    }

    expect(await revision('empty'), endsWith('|false'));
    expect(await revision('hidden'), endsWith('|false'));
    expect(await revision('full'), endsWith('|true'));
  });
}
