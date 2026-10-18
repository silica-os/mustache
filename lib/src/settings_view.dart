// The Settings window (kit `Apps/Mustache/Settings General|Tags|Sidebar|Advanced`): 600 wide, a
// title bar with the window controls, the Segmented Control, Icon + Label under it (four panes
// of 80, 52 tall) and grouped rows (24 pt from the sides, 12 pt radius cards, 36 pt rows). The window
// is as tall as the pane. Every row changes a setting Mustache follows at once (the windows
// watch settings.json); what Mustache cannot do yet (the desktop's volumes, filename
// extensions, suggested names, the sidebar's disks) is not drawn.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';
import 'settings.dart';
import 'tags.dart';

const double settingsWidth = 600;
const double _toolbar = AmalfiToolbarMetrics.toolbarHeight;

/// The Segmented Control, Icon + Label under the title bar.
const double _bar = AmalfiIconLabelMetrics.barHeight;

const List<(SettingsPane, String)> _panes = [
  (SettingsPane.general, 'gear'),
  (SettingsPane.tags, 'tag'),
  (SettingsPane.sidebar, 'sidebar'),
  (SettingsPane.advanced, 'sliders'),
];

enum SettingsPane { general, tags, sidebar, advanced }

/// The sidebar items the Sidebar pane can hide: their keys in `hiddenSidebar`.
const List<PlaceKind> pinnedKinds = [
  PlaceKind.desktop,
  PlaceKind.documents,
  PlaceKind.downloads,
  PlaceKind.pictures,
  PlaceKind.music,
  PlaceKind.videos,
];

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.settings,
    required this.places,
    this.onHeight,
    this.onTitle,
    this.initial = SettingsPane.general,
  });

  final Settings settings;

  /// The places of the sidebar (their names and folders).
  final List<Place> places;

  /// The window should be this tall now (the pane's content under the toolbar).
  final ValueChanged<double>? onHeight;

  /// The window title: the name of the pane.
  final ValueChanged<String>? onTitle;
  final SettingsPane initial;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late SettingsPane _pane = widget.initial;
  final GlobalKey _content = GlobalKey();
  double _reported = 0;
  String? _titled;

  Settings get _s => widget.settings;

  @override
  void initState() {
    super.initState();
    _s.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    _s.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _report() {
    if (!mounted) return;
    final box = _content.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final height = _toolbar + _bar + box.size.height;
      if (height != _reported) {
        _reported = height;
        widget.onHeight?.call(height);
      }
    }
    final title = _title(_pane);
    if (title != _titled) {
      _titled = title;
      widget.onTitle?.call(title);
    }
  }

  String _title(SettingsPane p) => switch (p) {
    SettingsPane.general => l10n.settingsGeneral,
    SettingsPane.tags => l10n.settingsTags,
    SettingsPane.sidebar => l10n.settingsSidebar,
    SettingsPane.advanced => l10n.settingsAdvanced,
  };

  void _choose(SettingsPane pane) {
    setState(() => _pane = pane);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return ColoredBox(
      color: colors.surfaceWindow,
      child: Stack(
        children: [
          // The title bar keeps the window controls; the panes switch with the Segmented
          // Control, Icon + Label (4 panes of 80) under it.
          Positioned(
            left: 0,
            right: 0,
            top: _toolbar,
            height: _bar,
            child: Center(
              child: AmalfiIconLabelSegmentedControl(
                key: const ValueKey('settings tabs'),
                tabs: [
                  for (final (pane, icon) in _panes)
                    AmalfiIconLabelSegment(label: _title(pane), symbol: icon),
                ],
                selected: _pane.index,
                onChanged: (i) => _choose(SettingsPane.values[i]),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _toolbar + _bar,
            child: SingleChildScrollView(
              child: KeyedSubtree(
                key: _content,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: switch (_pane) {
                    SettingsPane.general => _General(
                      widget.settings,
                      widget.places,
                    ),
                    SettingsPane.tags => _TagsPane(widget.settings),
                    SettingsPane.sidebar => _SidebarPane(
                      widget.settings,
                      widget.places,
                    ),
                    SettingsPane.advanced => _Advanced(widget.settings),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Rows and groups ------------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({this.heading, required this.rows, this.last = false});

  final String? heading;
  final List<Widget> rows;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: SizedBox(
                height: 16,
                child: Text(
                  heading!,
                  style: AmalfiType.callout(
                    color: colors.textSecondary,
                  ).copyWith(fontSize: 12, height: 16 / 12),
                ),
              ),
            ),
          _Group(children: rows),
        ],
      ),
    );
  }
}

/// A card: rows with a 1 pt separator between them, inset by 12.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surfaceSidebar,
        shape: AmalfiSmoothBorder(radius: 12),
      ),
      // The row's own height includes its separator (kit: rows at a 36 pitch).
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            Stack(
              children: [
                children[i],
                if (i < children.length - 1)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 0,
                    height: 1,
                    child: ColoredBox(color: colors.lineSeparator),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// `Apps/Settings/Row/Check`: a 16 pt checkbox at x 12, the title at x 40; [leading] (a tag
/// dot) goes between.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.leading,
    this.height = 36,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          spacing: 12,
          children: [
            AmalfiCheckbox(
              value: value,
              size: AmalfiControlSize.small,
              semanticLabel: label,
              onChanged: onChanged,
            ),
            ?leading,
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(!value),
                child: Text(
                  label,
                  maxLines: 1,
                  style: AmalfiType.body(color: colors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `Apps/Settings/Row/Switch`: the title at x 12 and a switch at x 500, 40 tall.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  style: AmalfiType.body(color: colors.textPrimary),
                ),
              ),
              AmalfiSwitch(
                value: value,
                size: AmalfiControlSize.small,
                semanticLabel: label,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `Apps/Settings/Row/Popup`: the title at x 12, a 108 × 24 pop-up at x 412, 40 tall.
class _PopupRow<T> extends StatelessWidget {
  const _PopupRow({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<AmalfiPopUpItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 32),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                style: AmalfiType.body(color: colors.textPrimary),
              ),
            ),
            AmalfiPopUpButton<T>(
              size: AmalfiControlSize.small,
              width: 108,
              semanticLabel: label,
              items: items,
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// Panes ----------------------------------------------------------------------------------------

class _General extends StatelessWidget {
  const _General(this.s, this.places);
  final Settings s;
  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    final folders = [
      for (final kind in [PlaceKind.home, ...pinnedKinds])
        for (final p in places)
          if (p.kind == kind)
            AmalfiPopUpItem(
              value: kind.name,
              label: kind == PlaceKind.home ? l10n.settingsHomeFolder : p.label,
            ),
    ];
    final value = folders.any((i) => i.value == s.newWindowFolder)
        ? s.newWindowFolder
        : PlaceKind.home.name;
    return _Section(
      heading: l10n.settingsWindowsAndNames,
      last: true,
      rows: [
        _PopupRow<String>(
          key: const ValueKey('setting new window folder'),
          label: l10n.settingsNewWindowsShow,
          items: folders,
          value: value,
          onChanged: (v) => s.newWindowFolder = v,
        ),
        _CheckRow(
          key: const ValueKey('setting tabs'),
          label: l10n.settingsOpenInTabs,
          value: s.tabsForNewWindows,
          onChanged: (v) => s.tabsForNewWindows = v,
        ),
      ],
    );
  }
}

class _TagsPane extends StatelessWidget {
  const _TagsPane(this.s);
  final Settings s;

  @override
  Widget build(BuildContext context) {
    final dark = AmalfiTheme.of(context).isDark;
    final hidden = s.hiddenTags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          heading: l10n.settingsShowTags,
          rows: [
            for (final c in TagColor.values)
              _CheckRow(
                key: ValueKey('setting tag ${c.name}'),
                label: tagName(c),
                value: !hidden.contains(c.name),
                height: 32,
                leading: TagDot(
                  color: sidebarTagColor(c, dark: dark),
                  side: 12,
                  ring: false,
                ),
                onChanged: (on) => s.hiddenTags = [
                  for (final h in hidden)
                    if (h != c.name) h,
                  if (!on) c.name,
                ],
              ),
          ],
        ),
        _FavouriteTags(s),
        _Group(
          children: [
            _SwitchRow(
              key: const ValueKey('setting colour folders'),
              label: l10n.settingsColourFolders,
              value: s.colourFolders,
              onChanged: (v) => s.colourFolders = v,
            ),
          ],
        ),
      ],
    );
  }
}

/// The seven favourite tag discs (26 pt at a 34 pitch from x 12): dragging one reorders them.
class _FavouriteTags extends StatefulWidget {
  const _FavouriteTags(this.s);
  final Settings s;

  @override
  State<_FavouriteTags> createState() => _FavouriteTagsState();
}

class _FavouriteTagsState extends State<_FavouriteTags> {
  late List<TagColor> _order = favouriteOrder(widget.s.favouriteTags);
  TagColor? _dragging;
  double _left = 0;

  static const double _pitch = 34;
  static const double _disc = 26;
  static const double _first = 12;

  @override
  void didUpdateWidget(_FavouriteTags old) {
    super.didUpdateWidget(old);
    if (_dragging == null) _order = favouriteOrder(widget.s.favouriteTags);
  }

  void _drag(TagColor c, double dx) {
    _left = (_left + dx).clamp(_first, _first + _pitch * 6);
    final target = ((_left - _first) / _pitch).round().clamp(0, 6);
    final from = _order.indexOf(c);
    if (target != from) {
      _order
        ..removeAt(from)
        ..insert(target, c);
    }
    setState(() {});
  }

  void _end() {
    widget.s.favouriteTags = [for (final c in _order) c.name];
    setState(() => _dragging = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final dark = AmalfiTheme.of(context).isDark;
    return _Section(
      heading: l10n.settingsFavouriteTags,
      rows: [
        SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final colour in _order)
                Positioned(
                  key: ValueKey('favourite ${colour.name}'),
                  left: colour == _dragging
                      ? _left
                      : _first + _pitch * _order.indexOf(colour),
                  top: 8,
                  width: _disc,
                  height: _disc,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => setState(() {
                      _dragging = colour;
                      _left = _first + _pitch * _order.indexOf(colour);
                    }),
                    onHorizontalDragUpdate: (d) => _drag(colour, d.delta.dx),
                    onHorizontalDragEnd: (_) => _end(),
                    onHorizontalDragCancel: _end,
                    child: Semantics(
                      label: tagName(colour),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tagPaletteColor(colour, dark: dark),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                top: 42,
                right: 12,
                height: 14,
                child: Text(
                  l10n.settingsFavouritesCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AmalfiType.caption(color: colors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane(this.s, this.places);
  final Settings s;
  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    final hidden = s.hiddenSidebar;
    Widget row(String id, String label) => _CheckRow(
      key: ValueKey('setting sidebar $id'),
      label: label,
      value: !hidden.contains(id),
      onChanged: (on) => s.hiddenSidebar = [
        for (final h in hidden)
          if (h != id) h,
        if (!on) id,
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          heading: l10n.sidebarPinned,
          rows: [
            for (final kind in pinnedKinds)
              for (final p in places)
                if (p.kind == kind) row(kind.name, p.label),
          ],
        ),
        _Section(
          heading: l10n.sidebarPlaces,
          rows: [
            row(PlaceKind.home.name, l10n.settingsHomeFolder),
            row(PlaceKind.trash.name, l10n.trash),
          ],
        ),
        _Section(
          heading: l10n.sidebarTags,
          last: true,
          rows: [row('tags', l10n.sidebarTags)],
        ),
      ],
    );
  }
}

class _Advanced extends StatelessWidget {
  const _Advanced(this.s);
  final Settings s;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Section(
        heading: l10n.settingsConfirmBefore,
        rows: [
          _CheckRow(
            key: const ValueKey('setting confirm extension'),
            label: l10n.settingsConfirmExtension,
            value: s.confirmExtension,
            onChanged: (v) => s.confirmExtension = v,
          ),
          _CheckRow(
            key: const ValueKey('setting confirm trash'),
            label: l10n.settingsConfirmTrash,
            value: s.confirmEmptyTrash,
            onChanged: (v) => s.confirmEmptyTrash = v,
          ),
        ],
      ),
      _Section(
        heading: l10n.trash,
        rows: [
          _SwitchRow(
            key: const ValueKey('setting trash cleanup'),
            label: l10n.settingsTrashCleanup,
            value: s.trashCleanup,
            onChanged: (v) => s.trashCleanup = v,
          ),
        ],
      ),
      _Section(
        heading: l10n.settingsFoldersOnTop,
        rows: [
          _CheckRow(
            key: const ValueKey('setting folders windows'),
            label: l10n.settingsFoldersOnTopWindows,
            value: s.foldersOnTopWindows,
            onChanged: (v) => s.foldersOnTopWindows = v,
          ),
          _CheckRow(
            key: const ValueKey('setting folders desktop'),
            label: l10n.settingsFoldersOnTopDesktop,
            value: s.foldersOnTopDesktop,
            onChanged: (v) => s.foldersOnTopDesktop = v,
          ),
        ],
      ),
      _Section(
        heading: l10n.settingsWhenSearching,
        last: true,
        rows: [
          _PopupRow<String>(
            key: const ValueKey('setting search scope'),
            label: l10n.settingsSearchIn,
            items: [
              AmalfiPopUpItem(value: 'computer', label: l10n.thisComputer),
              AmalfiPopUpItem(
                value: 'folder',
                label: l10n.settingsCurrentFolder,
              ),
            ],
            value: s.searchScope,
            onChanged: (v) => s.searchScope = v,
          ),
        ],
      ),
    ],
  );
}
