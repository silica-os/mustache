import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/external.dart';
import 'package:mustache/src/folder_style.dart';
import 'package:mustache/src/xattr.dart';

/// The GIO metadata store, in memory.
class FakeMetadata implements FolderMetadata {
  final Map<String, String> values = {};
  int reads = 0;

  @override
  String? read(String path) {
    reads++;
    return values[path];
  }

  @override
  bool write(String path, String? value) {
    value == null ? values.remove(path) : values[path] = value;
    return true;
  }
}

/// Extended attributes and tags, in memory; `supported: false` acts like a USB stick.
class FakeDisk {
  FakeDisk({this.supported = true});
  final bool supported;
  final Map<String, Map<String, String>> attributes = {};
  final Map<String, List<String>> tags = {};

  ({String? value, bool unsupported}) read(String path, String name) => (
    value: supported ? (attributes[path]?[name]) : null,
    unsupported: !supported,
  );

  AttributeWrite write(String path, String name, String value) {
    if (!supported) return AttributeWrite.unsupported;
    if (value.isEmpty) {
      attributes[path]?.remove(name);
    } else {
      (attributes[path] ??= {})[name] = value;
    }
    return AttributeWrite.done;
  }

  FolderStyles styles(FakeMetadata metadata) => FolderStyles(
    readAttribute: read,
    writeAttribute: write,
    readTags: (path) => tags[path] ?? const [],
    metadata: metadata,
  );
}

/// A temporary folder under home (/tmp may be tmpfs without user attributes).
Directory homeTemp(String name) {
  final cache = Directory('${Platform.environment['HOME']}/.cache')
    ..createSync(recursive: true);
  final dir = cache.createTempSync(name);
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('the stored JSON: valid fields only', () {
    expect(
      FolderStyle.parse('{"tint":"#E8336D","symbol":"music-note"}'),
      const FolderStyle(tint: '#e8336d', symbol: 'music-note'),
    );
    expect(FolderStyle.parse('{"tint":"red"}'), const FolderStyle(tint: 'red'));
    expect(
      FolderStyle.parse('{"tint":"pink","symbol":"../x"}'),
      isNull,
      reason: 'neither part is usable',
    );
    expect(FolderStyle.parse('not json'), isNull);
    expect(FolderStyle.parse('[1]'), isNull);
    expect(FolderStyle.parse(''), isNull);
    expect(
      const FolderStyle(tint: '#e8336d', symbol: 'music-note').encode(),
      '{"tint":"#e8336d","symbol":"music-note"}',
    );
    expect(const FolderStyle(symbol: 'star').encode(), '{"symbol":"star"}');
  });

  test(
    'the emoji: stored as {"emoji":"🎵"}, replaces the symbol, validated',
    () {
      expect(
        FolderStyle.parse('{"emoji":"🎵"}'),
        const FolderStyle(emoji: '🎵'),
      );
      expect(const FolderStyle(emoji: '🎵').encode(), '{"emoji":"🎵"}');
      // Both stored: the emoji wins, as on screen.
      expect(
        FolderStyle.parse('{"emoji":"🎵","symbol":"star"}'),
        const FolderStyle(emoji: '🎵'),
      );
      // Not an emoji: plain letters, spaces, controls, too long.
      for (final bad in ['a', '', 'ab c', '\n', '🎵' * 13]) {
        expect(
          FolderStyle.parse(jsonEncode({'emoji': bad})),
          isNull,
          reason: bad,
        );
      }
      expect(validEmoji('🏳️\u200d🌈'), isTrue);
      expect(validEmoji('1\ufe0f\u20e3'), isTrue, reason: 'a keycap');
      // One replaces the other.
      const symbol = FolderStyle(tint: 'red', symbol: 'star');
      expect(
        symbol.withEmoji('🎵'),
        const FolderStyle(tint: 'red', emoji: '🎵'),
      );
      expect(
        const FolderStyle(emoji: '🎵').withSymbol('star'),
        const FolderStyle(symbol: 'star'),
      );
      expect(
        symbol.withEmoji(null),
        symbol,
        reason: 'clearing keeps the symbol',
      );
    },
  );

  test('user.silica.folder on a real folder, and the checked reads', () {
    final dir = homeTemp('mustache-folder-style');
    final folder = Directory('${dir.path}/Musica')..createSync();
    final probe = readAttributeChecked(folder.path, folderStyleAttribute);
    expect(probe.value, isNull);
    if (probe.unsupported ||
        !writeAttribute(folder.path, folderStyleAttribute, '{"tint":"red"}')) {
      markTestSkipped('the file system does not support user attributes');
      return;
    }
    final metadata = FakeMetadata();
    final styles = FolderStyles(metadata: metadata);
    expect(styles.stored(folder.path), const FolderStyle(tint: 'red'));
    const style = FolderStyle(tint: '#e8336d', symbol: 'music-note');
    expect(styles.save(folder.path, style), isTrue);
    expect(
      readAttribute(folder.path, folderStyleAttribute),
      '{"tint":"#e8336d","symbol":"music-note"}',
    );
    expect(styles.look(folder.path), (
      symbol: 'music-note',
      tint: '#e8336d',
      emoji: null,
    ));
    // Reset removes the attribute; removing it twice is fine.
    expect(styles.save(folder.path, const FolderStyle()), isTrue);
    expect(styles.save(folder.path, const FolderStyle()), isTrue);
    expect(readAttribute(folder.path, folderStyleAttribute), isNull);
    expect(styles.stored(folder.path), isNull);
    // The disk supports attributes: the GIO store is never asked.
    expect(metadata.reads, 0);
    // A vanished folder: a failure, not an exception.
    expect(
      writeAttributeChecked('${dir.path}/gone', folderStyleAttribute, '{}'),
      AttributeWrite.failed,
    );
    expect(styles.save('${dir.path}/gone', style), isFalse);
  });

  test('a file system without user attributes is told from a missing one', () {
    // procfs has no user attributes (like some USB and network disks).
    if (!Directory('/proc/self').existsSync()) {
      markTestSkipped('no /proc');
      return;
    }
    expect(
      readAttributeChecked('/proc/self', folderStyleAttribute).unsupported,
      isTrue,
    );
  });

  test('a disk without attributes keeps the style in the GIO store', () {
    final metadata = FakeMetadata();
    final disk = FakeDisk(supported: false);
    final styles = disk.styles(metadata);
    expect(styles.stored('/media/usb/Foto'), isNull);
    expect(metadata.reads, 1);
    expect(
      styles.save('/media/usb/Foto', const FolderStyle(symbol: 'star')),
      isTrue,
    );
    expect(metadata.values['/media/usb/Foto'], '{"symbol":"star"}');
    expect(styles.look('/media/usb/Foto').symbol, 'star');
    expect(styles.save('/media/usb/Foto', const FolderStyle()), isTrue);
    expect(metadata.values, isEmpty);
    // A disk with attributes does not write to the GIO store.
    final supported = FakeDisk();
    final other = FakeMetadata();
    supported
        .styles(other)
        .save('/home/a/Foto', const FolderStyle(tint: 'blue'));
    expect(other.values, isEmpty);
    expect(
      supported.attributes['/home/a/Foto']?[folderStyleAttribute],
      '{"tint":"blue"}',
    );
  });

  test('gio info output and the real store under flutter test', () {
    expect(
      parseGioInfo(
        'uri: file:///media/usb/Foto\n'
        'attributes:\n'
        '  metadata::silica-folder: {"tint":"red"}\n',
      ),
      '{"tint":"red"}',
    );
    expect(parseGioInfo('attributes:\n'), isNull);
    // Tests start nothing: the real GIO store answers nothing and writes nothing.
    expect(startsNothing, isTrue);
    expect(runQuietly('gio', ['info', '/']), isNull);
    expect(const GioFolderMetadata().read('/'), isNull);
    expect(const GioFolderMetadata().write('/', '{}'), isFalse);
  });

  test(
    'tint order: the last assigned colour tag, then an older custom tint',
    () {
      final disk = FakeDisk();
      final styles = disk.styles(FakeMetadata());
      const path = '/home/a/Lavoro';
      expect(styles.look(path), (symbol: null, tint: null, emoji: null));
      disk.tags[path] = ['Progetti', 'Verde', 'Red'];
      styles.invalidate([path]);
      expect(styles.look(path).tint, 'red', reason: 'the last colour tag');
      disk.tags[path] = ['Grigio'];
      styles.invalidate([path]);
      expect(styles.look(path).tint, 'gray', reason: 'a localized name');
      styles.save(path, const FolderStyle(symbol: 'star'));
      expect(styles.look(path), (symbol: 'star', tint: 'gray', emoji: null));
      // An older custom tint only counts when there is no colour tag.
      styles.save(path, const FolderStyle(tint: '#e8336d', symbol: 'star'));
      expect(styles.look(path).tint, 'gray');
      disk.tags[path] = ['Progetti'];
      styles.invalidate([path]);
      expect(styles.look(path), (symbol: 'star', tint: '#e8336d', emoji: null));
    },
  );

  test('invalidating redraws only for folders already shown', () {
    final styles = FakeDisk().styles(FakeMetadata());
    var redraws = 0;
    styles.addListener(() => redraws++);
    styles.invalidate(['/a']);
    expect(redraws, 0);
    styles.look('/a');
    styles.invalidate(['/a', '/b']);
    expect(redraws, 1);
  });
}
