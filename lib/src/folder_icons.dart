// Folder icons: the system composes them (`Thumbnails1.Icon` of the daemon: colour, symbol, the
// sheet of a folder with items). This file knows when a folder's icon must be asked again and
// draws the emoji of FOLDER-CUSTOM on top.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'folder_style.dart';

/// Per folder: its modification time when it was listed, and whether it has a visible item.
/// A folder's modification time changes when an item is added, removed or renamed, so one
/// `stat` per query tells whether the cached answer still holds; the listing runs again only
/// then, and it is not recursive.
final Map<String, (DateTime, bool)> _hasItems = {};

/// The folder at [path] contains at least one item. Hidden files (names starting with a dot)
/// do not count. A folder that cannot be read is empty.
bool folderHasItems(String path) {
  try {
    final directory = Directory(path);
    final changed = directory.statSync().modified;
    final cached = _hasItems[path];
    if (cached != null && cached.$1 == changed) return cached.$2;
    var found = false;
    for (final item in directory.listSync(followLinks: false)) {
      final slash = item.path.lastIndexOf('/');
      if (!item.path.substring(slash + 1).startsWith('.')) {
        found = true;
        break;
      }
    }
    // A folder changed within the filesystem's timestamp granularity could change again without
    // its modification time moving: such an answer is not cached.
    if (DateTime.now().difference(changed) < const Duration(seconds: 2)) {
      _hasItems.remove(path);
      return found;
    }
    if (_hasItems.length > 2000) _hasItems.clear();
    _hasItems[path] = (changed, found);
    return found;
  } on FileSystemException {
    return false;
  }
}

/// The icon of the folder at [path], drawn by the system. The revision changes with the folder's
/// colour, symbol and emptiness, which the daemon reads from the folder itself (`user.silica.folder`
/// and the colour tags), so the icon is asked again then. An emoji is not part of it:
/// [FolderEmoji] draws it on top.
ServiceSource folderSource(String path, {FolderStyles? styles}) {
  final look = (styles ?? folderStyles).look(path);
  return ServiceSource(
    Uri.file(path),
    isFolder: true,
    revision: '${look.tint}|${look.symbol}|${folderHasItems(path)}',
  );
}

/// Where the emoji sits on the folder canvas, and its size: the centre of the symbol box of the
/// generic folder (x 0.5, y 0.569) and a third of the icon (FOLDER-CUSTOM: ~30 pt on 96 pt).
const Offset folderEmojiCentre = Offset(0.5, 0.569);
const double folderEmojiRatio = 0.31;

/// [child] (a folder icon of [side]) with the folder's [emoji] on its front, in full colour; no
/// emoji: [child] as it is.
class FolderEmoji extends StatelessWidget {
  const FolderEmoji({
    super.key,
    required this.emoji,
    required this.side,
    required this.child,
  });

  final String? emoji;
  final double side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final emoji = this.emoji;
    if (emoji == null) return child;
    final box = side * folderEmojiRatio;
    return Stack(
      children: [
        child,
        Positioned(
          left: side * folderEmojiCentre.dx - box / 2,
          top: side * folderEmojiCentre.dy - box / 2,
          width: box,
          height: box,
          child: IgnorePointer(
            child: FittedBox(
              child: Text(
                emoji,
                key: const ValueKey('folder emoji'),
                style: const TextStyle(
                  fontSize: 100,
                  height: 1,
                  fontFamilyFallback: emojiFonts,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The colour emoji fonts, tried in order after the platform's own fallback.
const List<String> emojiFonts = ['Noto Color Emoji', 'Apple Color Emoji'];
