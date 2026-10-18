// The Mustache model, without UI: the contents of a folder, sorting, date and size formats,
// navigation history and the user's places.

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'l10n.dart';
import 'link_stat.dart';

/// An item of a folder.
@immutable
class Entry {
  const Entry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
    this.isLink = false,
  });

  final String name;
  final String path;
  final bool isDirectory;

  /// Bytes; irrelevant for folders.
  final int size;
  final DateTime modified;
  final bool isLink;

  bool get isHidden => name.startsWith('.');

  /// The extension without the dot, lowercase; empty for folders and names without a dot.
  String get extension {
    if (isDirectory) return '';
    final dot = name.lastIndexOf('.');
    return dot <= 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }
}

/// The columns to sort by.
enum SortKey { name, modified, size, kind }

/// The contents of `path`, without hidden files unless `showHidden`. A folder that cannot be read
/// (permissions, gone) gives an error, not an exception.
({List<Entry> entries, String? error}) listDirectory(
  String path, {
  bool showHidden = false,
}) {
  final entries = <Entry>[];
  try {
    for (final item in Directory(path).listSync(followLinks: false)) {
      final name = item.uri.pathSegments.lastWhere(
        (s) => s.isNotEmpty,
        orElse: () => item.path,
      );
      if (!showHidden && name.startsWith('.')) continue;
      final link = item is Link;
      // For links the target says whether it is a folder (it opens); date and size are the link's
      // (R3.2).
      final stat = link ? FileStat.statSync(item.path) : item.statSync();
      final own = link ? linkStat(item.path) : null;
      entries.add(
        Entry(
          name: Uri.decodeComponent(name),
          path: item.path,
          isDirectory: stat.type == FileSystemEntityType.directory,
          size: own?.size ?? (stat.size < 0 ? 0 : stat.size),
          modified: own?.modified ?? stat.modified,
          isLink: link,
        ),
      );
    }
  } on FileSystemException catch (error) {
    return (entries: entries, error: error.osError?.message ?? error.message);
  }
  return (entries: entries, error: null);
}

/// "Natural" comparison: numbers in names compare by value (`file 2` before `file 10`), letters
/// without case distinction.
int naturalCompare(String a, String b) {
  final x = a.toLowerCase();
  final y = b.toLowerCase();
  var i = 0;
  var j = 0;
  while (i < x.length && j < y.length) {
    final ci = x.codeUnitAt(i);
    final cj = y.codeUnitAt(j);
    if (_isDigit(ci) && _isDigit(cj)) {
      final si = i;
      final sj = j;
      while (i < x.length && _isDigit(x.codeUnitAt(i))) {
        i++;
      }
      while (j < y.length && _isDigit(y.codeUnitAt(j))) {
        j++;
      }
      final ni = BigInt.parse(x.substring(si, i));
      final nj = BigInt.parse(y.substring(sj, j));
      final c = ni.compareTo(nj);
      if (c != 0) return c;
      continue;
    }
    if (ci != cj) return ci.compareTo(cj);
    i++;
    j++;
  }
  final rest = (x.length - i).compareTo(y.length - j);
  return rest != 0 ? rest : a.compareTo(b);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// Items sorted by `key`. Ties are sorted by name; folders are mixed with files (mixed order is the
/// default, to be verified: MU-20).
/// Settings › Keep folders on top in windows when sorting by name (set from the settings).
bool windowsFoldersOnTop = true;

/// Sorts [entries]; sorting by name puts the folders first when [foldersFirst] (the windows'
/// setting by default).
List<Entry> sortEntries(
  Iterable<Entry> entries,
  SortKey key, {
  bool descending = false,
  String Function(Entry)? kindOf,
  bool? foldersFirst,
}) {
  final folders = key == SortKey.name && (foldersFirst ?? windowsFoldersOnTop);
  final kind = kindOf ?? kindLabel;
  int compare(Entry a, Entry b) {
    final byName = naturalCompare(a.name, b.name);
    if (folders && a.isDirectory != b.isDirectory) {
      // Folders stay on top whichever way the names run.
      return a.isDirectory ? -1 : 1;
    }
    final primary = switch (key) {
      SortKey.name => byName,
      SortKey.modified => a.modified.compareTo(b.modified),
      SortKey.size =>
        a.isDirectory != b.isDirectory
            ? (a.isDirectory ? -1 : 1)
            : a.size.compareTo(b.size),
      SortKey.kind => kind(a).compareTo(kind(b)),
    };
    return primary != 0 ? primary : byName;
  }

  final sorted = entries.toList()..sort(compare);
  if (!descending) return sorted;
  final reversed = sorted.reversed.toList();
  if (!folders) return reversed;
  // Descending names: each group reversed, the folders still first.
  return [
    ...reversed.where((e) => e.isDirectory),
    ...reversed.where((e) => !e.isDirectory),
  ];
}

const List<String> _units = ['KB', 'MB', 'GB', 'TB'];

/// Size in decimal units (1 KB = 1000 bytes, R3.2): bytes below 1000, KB and MB as integers, GB
/// and TB with two decimals and the language's decimal separator; "Zero bytes" for an empty file,
/// "--" for folders.
String formatSize(Entry entry) {
  if (entry.isDirectory) return '--';
  final bytes = entry.size;
  if (bytes == 0) return l10n.sizeZero;
  if (bytes < 1000) return l10n.sizeBytes(bytes);
  var value = bytes / 1000;
  var unit = 0;
  while (value.round() >= 1000 && unit < _units.length - 1) {
    value /= 1000;
    unit++;
  }
  final text = unit < 2 ? value.round().toString() : decimal(value, 2);
  return '$text ${_units[unit]}';
}

/// "Today, 10:22", "Yesterday, 18:05", otherwise "Oct 3, 2026, 09:14" (R3.1: in Italian lowercase,
/// "oggi, 10:22" and "3 ott 2026, 09:14"; the year is always shown).
String formatDate(DateTime t, DateTime now) {
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return l10n.dateToday(clockTime(t));
  if (days == 1) return l10n.dateYesterday(clockTime(t));
  return shortDate(t);
}

const Map<String, String> _formats = {
  'png': 'PNG',
  'jpeg': 'JPEG',
  'gif': 'GIF',
  'webp': 'WebP',
  'svg+xml': 'SVG',
  'tiff': 'TIFF',
  'bmp': 'BMP',
  'heic': 'HEIC',
  'avif': 'AVIF',
  'x-tga': 'TGA',
  'wav': 'WAV',
  'x-wav': 'WAV',
  'vnd.wave': 'WAV',
  'aiff': 'AIFF',
  'x-aiff': 'AIFF',
  'mpeg': 'MP3',
  'flac': 'FLAC',
  'x-flac': 'FLAC',
  'ogg': 'Ogg',
  'x-vorbis+ogg': 'Ogg',
  'opus': 'Opus',
  'aac': 'AAC',
  'mp4': 'AAC',
};

const Set<String> _archives = {
  'application/zip',
  'application/gzip',
  'application/x-tar',
  'application/x-compressed-tar',
  'application/x-xz',
  'application/x-xz-compressed-tar',
  'application/x-bzip2',
  'application/x-bzip2-compressed-tar',
  'application/x-7z-compressed',
  'application/vnd.rar',
  'application/x-rar',
  'application/zstd',
  'application/x-zstd-compressed-tar',
};

/// The Kind column: a short name per family (R3.3), in our own words: folder, link, text, archive,
/// video, PDF, image and audio with the format, document for the rest. `mime` is the content type
/// (of the target, for a link).
String kindLabel(Entry entry, [String? mime]) {
  if (entry.isLink) return l10n.kindLink;
  if (entry.isDirectory) return l10n.kindFolder;
  final type = mime ?? 'application/octet-stream';
  final slash = type.indexOf('/');
  final top = slash < 0 ? type : type.substring(0, slash);
  final sub = slash < 0 ? '' : type.substring(slash + 1);
  if (type == 'application/pdf') return 'PDF';
  if (top == 'image') return l10n.kindImage(_formats[sub] ?? sub.toUpperCase());
  if (top == 'audio') return l10n.kindAudio(_formats[sub] ?? sub.toUpperCase());
  if (top == 'video') return l10n.kindVideo;
  if (_archives.contains(type)) {
    final ext = entry.extension;
    return ext.isEmpty ? l10n.kindArchive : l10n.kindArchiveExt(ext);
  }
  if (type == 'application/json') return 'JSON';
  if (type == 'text/markdown') return 'Markdown';
  if (top == 'text') return l10n.kindText;
  return l10n.kindDocument;
}

/// The history of a window: back and forward as in a browser.
class History {
  History(String start) : _stack = [start];

  final List<String> _stack;
  int _index = 0;

  String get current => _stack[_index];
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _stack.length - 1;

  /// Goes to `path`: the forward history is lost.
  void go(String path) {
    if (path == current) return;
    _stack
      ..removeRange(_index + 1, _stack.length)
      ..add(path);
    _index = _stack.length - 1;
  }

  /// The places before this one, the most recent first (the Back menu).
  List<String> get backList => [
    for (var i = _index - 1; i >= 0; i--) _stack[i],
  ];

  /// The places after this one, the nearest first (the Forward menu).
  List<String> get forwardList => _stack.sublist(_index + 1);

  /// Jumps by `steps` places (negative: back), within the history.
  bool jump(int steps) {
    final target = _index + steps;
    if (steps == 0 || target < 0 || target >= _stack.length) return false;
    _index = target;
    return true;
  }

  bool back() {
    if (!canGoBack) return false;
    _index--;
    return true;
  }

  bool forward() {
    if (!canGoForward) return false;
    _index++;
    return true;
  }
}

/// The folder containing `path`, or null at the root.
String? parentOf(String path) {
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (trimmed == '/') return null;
  final slash = trimmed.lastIndexOf('/');
  if (slash < 0) return null;
  return slash == 0 ? '/' : trimmed.substring(0, slash);
}

/// The name to show for a folder: the last segment, "/" for the root.
String displayName(String path) {
  if (path == '/') return '/';
  final parts = path.split('/').where((s) => s.isNotEmpty);
  return parts.isEmpty ? path : parts.last;
}

/// A sidebar place.
@immutable
class Place {
  const Place(this.label, this.path, this.kind);

  final String label;
  final String path;
  final PlaceKind kind;
}

/// The folder new windows show: the place chosen in Settings › General (`home` by default),
/// [fallback] if there is no such place.
String newWindowPath(String? choice, List<Place> places, String fallback) {
  for (final p in places) {
    if (p.kind.name == (choice ?? 'home') &&
        p.kind != PlaceKind.tag &&
        p.kind != PlaceKind.search) {
      return p.path;
    }
  }
  return fallback;
}

enum PlaceKind {
  home,
  desktop,
  documents,
  downloads,
  pictures,
  music,
  videos,
  trash,

  /// A tag (path `tag:<name>`): shows the items that carry it.
  tag,

  /// A saved search (path `search:<file>`): runs it.
  search,
}

/// The name of the virtual view of the recently used files, kept where a tag name is (it
/// cannot be one: tag names are not made of control characters).
const String recentsView = '\u0001recents';

/// The prefix of tag paths in the sidebar.
const String tagPathPrefix = 'tag:';

/// The path of a saved search's sidebar row: `search:` and the `.search` file.
const String searchPathPrefix = 'search:';

/// The user folders from `~/.config/user-dirs.dirs` (xdg-user-dirs specification), with the folder
/// name as the label; only those that exist.
List<Place> userPlaces({required String home, String? userDirs}) {
  final dirs = <String, String>{};
  for (final line in (userDirs ?? '').split('\n')) {
    final match = RegExp(r'^XDG_(\w+)_DIR="(.*)"$').firstMatch(line.trim());
    if (match == null) continue;
    dirs[match.group(1)!] = match.group(2)!.replaceFirst(r'$HOME', home);
  }
  final places = <Place>[Place(displayName(home), home, PlaceKind.home)];
  for (final (key, kind) in [
    ('DESKTOP', PlaceKind.desktop),
    ('DOCUMENTS', PlaceKind.documents),
    ('DOWNLOAD', PlaceKind.downloads),
    ('PICTURES', PlaceKind.pictures),
    ('MUSIC', PlaceKind.music),
    ('VIDEOS', PlaceKind.videos),
  ]) {
    final path = dirs[key];
    if (path == null || path == home || !Directory(path).existsSync()) continue;
    places.add(Place(displayName(path), path, kind));
  }
  return places;
}

/// The user's Trash (freedesktop Trash specification): `$XDG_DATA_HOME/Trash/files`.
Place trashPlace({required String home, String? dataHome}) {
  final base = (dataHome == null || dataHome.isEmpty)
      ? '$home/.local/share'
      : dataHome;
  return Place(l10n.trash, '$base/Trash/files', PlaceKind.trash);
}

/// The item at `path` (null if it does not exist): like a row of `listDirectory`.
Entry? entryAt(String path) {
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    final link = type == FileSystemEntityType.link;
    final stat = FileStat.statSync(path);
    final own = link ? linkStat(path) : null;
    return Entry(
      name: displayName(path),
      path: path,
      isDirectory: stat.type == FileSystemEntityType.directory,
      size: own?.size ?? (stat.size < 0 ? 0 : stat.size),
      modified: own?.modified ?? stat.modified,
      isLink: link,
    );
  } on FileSystemException {
    return null;
  }
}

/// The content view (spec/list-view.md–6): icons (⌘1), list (⌘2), columns (⌘3).
enum ViewMode { icons, list, columns, gallery }
