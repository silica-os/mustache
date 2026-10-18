// Tags in the window (MU-62): reading from extended attributes, assignment from the row of circles
// in the context menu (R10.3), the Tags section of the sidebar and the view of the items with a tag
// (R2.15).

part of 'window.dart';

/// How many items the search for a tag in home examines at most.
const int tagScanLimit = 50000;

extension _Tags on _MustacheWindowState {
  /// The tags of an item, read once per load.
  List<String> _tagsOf(Entry entry) =>
      _tagCache[entry.path] ??= readTags(entry.path);

  /// The color tags all the chosen items have.
  Set<TagColor> _sharedColors(List<Entry> items) {
    if (items.isEmpty) return const {};
    return {
      for (final c in TagColor.values)
        if (items.every((e) => _tagsOf(e).any((t) => tagColor(t) == c))) c,
    };
  }

  /// A click on a circle: if all items have it, it is removed, otherwise added.
  void _toggleTag(TagColor color, [List<Entry>? targets]) {
    final name = tagName(color);
    final items = targets ?? _selection;
    bool has(List<String> tags) => tags.any((t) => tagColor(t) == color);
    final remove = items.isNotEmpty && items.every((e) => has(_tagsOf(e)));
    var failed = false;
    for (final e in items) {
      final tags = [..._tagsOf(e)];
      if (remove) {
        tags.removeWhere((t) => tagColor(t) == color);
      } else if (!has(tags)) {
        tags.add(name);
      }
      if (writeTags(e.path, tags)) {
        _tagCache[e.path] = tags;
        // A colour tag tints a folder.
        if (e.isDirectory) folderStyles.invalidate([e.path]);
      } else {
        failed = true;
      }
    }
    _update(() {});
    if (failed) {
      _showError(l10n.tagError, l10n.tagErrorDetail);
    }
  }

  /// A tag typed in the preview pane field.
  void _addTag(Entry entry, String tag) {
    final tags = [..._tagsOf(entry)];
    if (tags.contains(tag)) return;
    _setTagList(entry, [...tags, tag]);
  }

  /// The tags left after one was removed from a tag field (Get Info, preview pane), or the field
  /// was cleared.
  void _setTagList(Entry entry, List<String> tags) {
    if (writeTags(entry.path, tags)) {
      _update(() => _tagCache[entry.path] = tags);
      _infoRevision.value++;
      // A colour tag tints a folder: the style (and its thumbnail) is read again.
      if (entry.isDirectory) folderStyles.invalidate([entry.path]);
    } else {
      _showError(l10n.tagError, l10n.tagErrorDetail);
    }
  }

  /// The Tags popover of the toolbar (kit `Toolbar/Tags Popover`): the first favourite colours, each
  /// with its dot and a check when every selected item has it, and Show All… for the rest.
  Future<void> _openTagsPopover(Rect anchor) async {
    final host = _bodyKey.currentContext;
    final items = _selection;
    if (host == null || items.isEmpty) return;
    var all = false;
    var keepOpen = false;
    await showAmalfiPopover(
      context: host,
      anchor: anchor,
      padding: AmalfiPopoverMetrics.listPadding,
      builder: (context, dismiss) => StatefulBuilder(
        builder: (context, setPopover) {
          final assigned = _sharedColors(items);
          final dark = AmalfiTheme.of(context).isDark;
          // The first five of Settings › Tags › Favourite tags (kit: five and Show All…).
          final ordered = favouriteOrder(
            widget.settings?.favouriteTags ?? const [],
          );
          final colors = all ? ordered : ordered.take(5).toList();
          return AmalfiPopoverList(
            width: 216,
            autofocus: true,
            // Choosing a colour closes it; Show All… keeps it open with the whole list.
            onDismiss: () {
              if (keepOpen) {
                keepOpen = false;
                return;
              }
              dismiss();
            },
            entries: [
              AmalfiMenuSection(l10n.toolbarTags),
              for (final color in colors)
                AmalfiMenuAction(
                  tagName(color),
                  icon: TagDot(
                    color: menuTagColor(color, dark: dark),
                    side: 12,
                    ring: false,
                  ),
                  checked: assigned.contains(color),
                  onSelected: () => _toggleTag(color, items),
                ),
              if (!all && ordered.length > colors.length) ...[
                const AmalfiMenuDivider(),
                AmalfiMenuAction(
                  l10n.tagsShowAll,
                  onSelected: () {
                    keepOpen = true;
                    setPopover(() => all = true);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
    if (mounted) _focus.requestFocus();
  }

  /// The Actions menu of the toolbar (kit `Toolbar/Actions Menu`): the menu of the selected
  /// items, or the folder's menu without a selection.
  List<AmalfiMenuEntry> _toolbarActions() {
    final items = _selection;
    return items.isEmpty ? _backgroundMenu() : _itemsMenu(items);
  }

  /// The actions at the bottom of the preview pane, depending on the choice (spec/preview-pane.md): Edit for
  /// images and PDFs (with the default app), More (the item menu) always.
  List<PaneAction> _paneActions() {
    final items = _selection;
    if (items.isEmpty) return const [];
    final one = items.length == 1 ? items.single : null;
    final editable =
        one != null &&
        !one.isDirectory &&
        (hasThumbnail(one.name) || one.extension == 'pdf');
    return [
      if (editable) PaneAction(l10n.paneEdit, 'pencil', (_) => _openEntry(one)),
      PaneAction(
        l10n.paneMore,
        'ellipsis-circle',
        (at) => _openContextMenu(items.first, at),
      ),
    ];
  }

  /// The Tags submenu of the context menu: one item per color with its dot, checked when every
  /// item has the tag.
  AmalfiMenuAction _tagMenu(List<Entry> items) {
    final assigned = _sharedColors(items);
    final dark = AmalfiTheme.of(context).isDark;
    return AmalfiMenuAction(
      l10n.tagsMenu,
      submenu: [
        for (final color in favouriteOrder(
          widget.settings?.favouriteTags ?? const [],
        ))
          AmalfiMenuAction(
            tagName(color),
            icon: TagDot(
              color: menuTagColor(color, dark: dark),
              side: 12,
              ring: false,
            ),
            checked: assigned.contains(color),
            onSelected: () => _toggleTag(color, items),
          ),
      ],
    );
  }

  /// The places of the Tags section.
  List<Place> get _tagPlaces => [
    for (final color in TagColor.values)
      if (!(widget.settings?.hiddenTags.contains(color.name) ?? false))
        Place(tagName(color), '$tagPathPrefix${tagName(color)}', PlaceKind.tag),
  ];

  /// Shows the items in home with the tag, as the search finds them.
  Future<void> _showTag(String name) async {
    final home =
        widget.places
            .where((p) => p.kind == PlaceKind.home)
            .firstOrNull
            ?.path ??
        _history.current;
    final search = ++_tagSearch;
    _update(() {
      _tagView = name;
      _entries = const [];
      _selected.clear();
      _error = null;
    });
    final found = <Entry>[];
    var seen = 0;
    try {
      await for (final item in Directory(
        home,
      ).list(recursive: true, followLinks: false)) {
        if (search != _tagSearch || !mounted) return;
        if (++seen > tagScanLimit) break;
        // No hidden folders (.cache, .local…): tags are not put there.
        final relative = item.path.substring(home.length);
        if (relative.contains('/.')) continue;
        if (!readTags(item.path).any((t) => sameTag(t, name))) continue;
        final entry = entryAt(item.path);
        if (entry == null) continue;
        found.add(entry);
        _update(
          () => _entries = sortEntries(
            [...found],
            _sort,
            descending: _descending,
            kindOf: _kind,
          ),
        );
      }
    } on FileSystemException {
      // An unreadable folder stops the search: what was found stays.
    }
  }

  /// Shows the recently used files (Go › Recents), most recent first.
  void _showRecents() {
    final env = widget.iconsEnv ?? Platform.environment;
    final found = <Entry>[
      for (final path in recentPaths(env))
        if (entryAt(path) case final entry?) entry,
    ];
    _tagSearch++;
    _update(() {
      _tagView = recentsView;
      _entries = found;
      _selected.clear();
      _anchor = null;
      _error = null;
    });
  }
}
