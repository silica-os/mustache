// Recents: the files the user used lately, from the freedesktop `recently-used.xbel` (the
// "Desktop Bookmark Specification": `<bookmark href="file://…" visited="…">` entries in
// `$XDG_DATA_HOME/recently-used.xbel`). The window shows them as a virtual folder, most recent
// first.

import 'dart:io';

/// A file of the recently used list and when it was last used.
typedef RecentFile = ({String path, DateTime visited});

/// The `file://` bookmarks of [xbel], most recently visited first, at most [limit]. Other
/// schemes, malformed entries and duplicates are left out.
List<RecentFile> parseRecentlyUsed(String xbel, {int limit = 200}) {
  final found = <String, DateTime>{};
  for (final tag in RegExp(r'<bookmark\s[^>]*>').allMatches(xbel)) {
    final text = tag.group(0)!;
    final href = _attribute(text, 'href');
    if (href == null || !href.startsWith('file://')) continue;
    final String path;
    try {
      path = Uri.parse(_unescape(href)).toFilePath();
    } on Object {
      continue;
    }
    final visited =
        DateTime.tryParse(
          _attribute(text, 'visited') ?? _attribute(text, 'modified') ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final previous = found[path];
    if (previous == null || visited.isAfter(previous)) found[path] = visited;
  }
  final all = [for (final e in found.entries) (path: e.key, visited: e.value)]
    ..sort((a, b) => b.visited.compareTo(a.visited));
  return all.length > limit ? all.sublist(0, limit) : all;
}

String? _attribute(String tag, String name) {
  final m = RegExp('\\s$name="([^"]*)"').firstMatch(tag);
  return m?.group(1);
}

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// Where the list lives for [env].
String recentlyUsedPath(Map<String, String> env) {
  final data = env['XDG_DATA_HOME'];
  final base = data != null && data.isNotEmpty
      ? data
      : '${env['HOME'] ?? '/'}/.local/share';
  return '$base/recently-used.xbel';
}

/// The paths of the recently used files that still exist; empty if the list is missing or
/// cannot be read.
List<String> recentPaths(Map<String, String> env, {int limit = 200}) {
  try {
    final text = File(recentlyUsedPath(env)).readAsStringSync();
    return [
      for (final r in parseRecentlyUsed(text, limit: limit * 2))
        if (FileSystemEntity.typeSync(r.path) != FileSystemEntityType.notFound)
          r.path,
    ].take(limit).toList();
  } on FileSystemException {
    return const [];
  } on FormatException {
    return const [];
  }
}
