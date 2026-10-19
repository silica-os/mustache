// The sidebar (MU-10, MU-11; kit `Apps/Mustache/Sidebar`, components.md): 240 wide (200 at least),
// rows 28 tall on a 32 pt pitch, section headers 28 tall with a disclosure chevron, the selection
// a soft accent capsule; the tag rows have a 12 pt dot. On the sidebar surface with a 1 pt edge
// towards the content.
//
// Collapsing and expanding a section (MU-11): ~190 ms after a delay (measured, kept): the rows
// drop their text right away and slide up under the heading, which clips them.
//
// Width (MU-11 behaviour, Amalfi measures): minimum 200 pt, the content does not go below 316;
// released within 9 pt of the default width it snaps back to it; dragged closer than ~65 pt to
// the edge the sidebar hides.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'drag.dart';
import 'model.dart';
import 'tags.dart';

/// The row pitch: 32 tall, no gap between rows.
const double sidebarRow =
    AmalfiSidebarMetrics.rowHeight + AmalfiSidebarMetrics.rowGap;

/// The width of new windows (components.md: 240).
const double sidebarDefaultWidth = AmalfiSidebarMetrics.width;

/// Where the sidebar snaps when released near the default width (MU-11, around the default).
const double sidebarSnapWidth = sidebarDefaultWidth;
const double sidebarMinWidth = AmalfiSidebarMetrics.minWidth;
const double contentMinWidth = 316;

/// Released in this range the sidebar goes back to the default width.
const double sidebarSnapFrom = sidebarDefaultWidth - 9;
const double sidebarSnapTo = sidebarDefaultWidth + 9;

/// Dragged with the pointer closer than this to the left edge, the sidebar hides.
const double sidebarHideBelow = 65;

/// Collapsing and expanding a section (MU-11): ~190 ms after a delay.
const Duration sectionCollapse = Duration(milliseconds: 255);
const Duration sectionExpand = Duration(milliseconds: 308);
const double sectionCollapseDelay = 70 / 255;
const double sectionExpandDelay = 120 / 308;

/// A sidebar section: a title (empty: no heading) and its places.
@immutable
class SidebarSection {
  const SidebarSection(
    this.title,
    this.places, {
    this.glyphs = SidebarGlyphs.accent,
  });
  final String title;
  final List<Place> places;

  /// The colour of the section's glyphs (silica-ui#95: coloured by section, never per item).
  final SidebarGlyphs glyphs;
}

/// The glyph colour of a sidebar section.
enum SidebarGlyphs {
  /// `Accent/Amalfi`: Pinned and saved searches.
  accent,

  /// `Text/Secondary`: Places.
  secondary,
}

/// The sidebar width after a drag: between the minimum and the maximum that leaves 316 pt to the
/// content; 0 (hidden) with the pointer too close to the edge.
double dragWidth(double pointerX, double windowWidth) {
  if (pointerX < sidebarHideBelow) return 0;
  final max = math.max(sidebarMinWidth, windowWidth - contentMinWidth);
  return pointerX.clamp(sidebarMinWidth, max);
}

/// The width on release: close to the default it snaps to it.
double releaseWidth(double width) =>
    width >= sidebarSnapFrom && width <= sidebarSnapTo
    ? sidebarSnapWidth
    : width;

/// The Icon Kit symbol (silica-icons `symbols/regular`) for a place.
String symbolFor(PlaceKind kind) => switch (kind) {
  PlaceKind.home => 'house',
  PlaceKind.desktop => 'desktop',
  PlaceKind.documents => 'doc',
  PlaceKind.downloads => 'arrow-down',
  PlaceKind.pictures => 'photo',
  PlaceKind.music => 'music-note',
  PlaceKind.videos => 'video',
  PlaceKind.trash => 'trash',
  PlaceKind.tag => '',
  PlaceKind.search => 'search',
  PlaceKind.applications => 'square-grid-2x2',
  PlaceKind.volume => 'drive',
};

/// The tag dot of a sidebar row: 12 pt, the Amalfi palette.
const double sidebarTagDot = 12;

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelect,
    this.onDrop,
    this.onEject,
    this.topInset = 0,
  });

  /// The height of the blur strip over the top of the sidebar (the sidebar section of the
  /// toolbar): the rows start below it and scroll under it.
  final double topInset;

  /// Dropping dragged items on a place (R2.8): the row turns accent colored.
  final void Function(DragPayload payload, String destination)? onDrop;

  /// The eject button of a volume row (a mounted disk image).
  final ValueChanged<Place>? onEject;

  final List<SidebarSection> sections;

  /// The folder shown: its row is selected.
  final String current;
  final ValueChanged<Place> onSelect;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with TickerProviderStateMixin {
  final Map<String, AnimationController> _sections = {};
  String? _hovered;

  AnimationController _controller(String title) => _sections.putIfAbsent(
    title,
    () => AnimationController(
      vsync: this,
      duration: sectionExpand,
      reverseDuration: sectionCollapse,
      value: 1,
    )..addListener(() => setState(() {})),
  );

  @override
  void dispose() {
    for (final controller in _sections.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle(String title) {
    final controller = _controller(title);
    if (controller.status == AnimationStatus.reverse || controller.value == 0) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  bool _collapsing(String title) {
    final controller = _sections[title];
    return controller != null &&
        (controller.status == AnimationStatus.reverse || controller.value == 0);
  }

  /// How much of the section shows (0–1), with the measured delay before the movement.
  double _openness(String title) {
    final controller = _sections[title];
    if (controller == null) return 1;
    final collapsing = _collapsing(title);
    final delay = collapsing ? sectionCollapseDelay : sectionExpandDelay;
    // The time elapsed since the start, as a fraction of the duration.
    final elapsed = collapsing ? 1 - controller.value : controller.value;
    final moved = Curves.easeOut.transform(
      ((elapsed - delay) / (1 - delay)).clamp(0.0, 1.0),
    );
    return collapsing ? 1 - moved : moved;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final section in widget.sections) {
      if (section.places.isEmpty) continue;
      final title = section.title;
      final openness = title.isEmpty ? 1.0 : _openness(title);
      final textVisible = title.isEmpty || !_collapsing(title);
      // One child per section so that a collapsed section takes only its header: the gap between
      // the header and the first row is part of what slides away. Between sections the kit's 8 is
      // added here (the panel adds it itself only before its own headers).
      final colors = AmalfiTheme.of(context).colors;
      children.add(
        AmalfiSidebarGlyphColor(
          color: switch (section.glyphs) {
            SidebarGlyphs.accent => colors.accentAmalfi,
            SidebarGlyphs.secondary => colors.textSecondary,
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (children.isNotEmpty)
                const SizedBox(height: AmalfiSidebarMetrics.sectionGap),
              if (title.isNotEmpty)
                // The header is plain (kit `Sidebar`: `Header/Plain`) and shows its chevron while the
                // pointer is over it, or while the section is closed, so that it can be opened
                // (MU-11).
                MouseRegion(
                  onEnter: (_) => setState(() => _hovered = title),
                  onExit: (_) => setState(() {
                    if (_hovered == title) _hovered = null;
                  }),
                  child: AmalfiSidebarHeader(
                    key: ValueKey('header $title'),
                    title: title,
                    expanded: _hovered == title || _collapsing(title)
                        ? !_collapsing(title)
                        : null,
                    onToggle: () => _toggle(title),
                  ),
                ),
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: openness,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: title.isEmpty ? 0 : AmalfiSidebarMetrics.rowGap,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AmalfiSidebarMetrics.rowGap,
                      children: [
                        for (final place in section.places)
                          _row(place, showText: textVisible),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return AmalfiSidebarPanel(
      width: null,
      topInset: widget.topInset,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: children,
    );
  }

  Widget _row(Place place, {required bool showText}) {
    final onDrop = widget.onDrop;
    if (onDrop == null ||
        place.kind == PlaceKind.tag ||
        place.kind == PlaceKind.search) {
      return _rowContent(place, showText: showText, drop: false);
    }
    return FolderDropTarget(
      path: place.path,
      onDrop: onDrop,
      builder: (context, active) =>
          _rowContent(place, showText: showText, drop: active),
    );
  }

  Widget _rowContent(
    Place place, {
    required bool showText,
    required bool drop,
  }) {
    final selected = place.path == widget.current;
    // The Trash is named in the user's language; the other places by their folder or tag name.
    final label = !showText
        ? ''
        : place.kind == PlaceKind.trash
        ? l10n.trash
        : place.label;
    final key = ValueKey('place ${place.path}');
    final eject = widget.onEject;
    if (place.kind != PlaceKind.tag &&
        !drop &&
        (place.kind != PlaceKind.volume || eject == null)) {
      return AmalfiSidebarRow(
        key: key,
        label: label,
        icon: AmalfiSymbols.load(symbolFor(place.kind)),
        selected: selected,
        onTap: () => widget.onSelect(place),
      );
    }
    final color = place.kind == PlaceKind.tag ? tagColor(place.label) : null;
    final active = WindowActiveScope.of(context);
    return _SidebarRow(
      key: key,
      label: label,
      selected: selected,
      drop: drop,
      leading: place.kind == PlaceKind.tag
          ? TagDot(
              color: color == null
                  ? null
                  : !active && !drop
                  ? AmalfiTheme.of(context).colors.textSecondary
                  : sidebarTagColor(
                      color,
                      dark: AmalfiTheme.of(context).isDark,
                    ),
              side: sidebarTagDot,
              ring: false,
            )
          : AmalfiSymbol(
              symbolFor(place.kind),
              size: AmalfiSidebarMetrics.icon,
              color: drop
                  ? AmalfiTheme.of(context).colors.textOnAccent
                  : AmalfiTheme.of(context).colors.textSecondary,
            ),
      trailing: place.kind == PlaceKind.volume && eject != null
          ? EjectButton(
              key: ValueKey('eject ${place.path}'),
              volume: place.label,
              onPressed: () => eject(place),
            )
          : null,
      onTap: () => widget.onSelect(place),
    );
  }
}

/// A row with its own leading widget (a tag dot, the symbol on the drop highlight): the same
/// measures as `AmalfiSidebarRow` (32 tall, 12 padding, 20 icon slot, 8 gap, radius 8).
class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    super.key,
    required this.label,
    required this.leading,
    required this.selected,
    required this.drop,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final Widget leading;

  /// After the label (the eject button of a volume).
  final Widget? trailing;
  final bool selected;
  final bool drop;
  final VoidCallback onTap;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AmalfiTheme.of(context);
    final colors = theme.colors;
    // In an inactive window (kit `Selected Inactive`) the selection is a neutral capsule and the
    // label is Text/Secondary, as in `AmalfiSidebarRow`.
    final active = WindowActiveScope.of(context);
    final fill = widget.drop
        ? colors.accentAmalfi
        : widget.selected
        ? active
              ? colors.accentAmalfiSoft
              : theme.isDark
              ? colors.surfaceControl
              : colors.surfaceControlPressed
        : _hovered
        ? colors.lineSeparator
        : null;
    final labelColor = active ? colors.textPrimary : colors.textSecondary;
    final style = widget.selected && !widget.drop
        ? AmalfiType.bodyEmphasis(color: labelColor)
        : AmalfiType.body(
            color: widget.drop ? colors.textOnAccent : labelColor,
          );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: DecoratedBox(
          key: widget.drop ? const ValueKey('sidebar drop') : null,
          decoration: ShapeDecoration(
            color: fill,
            shape: AmalfiSmoothBorder(radius: AmalfiSidebarMetrics.radius),
          ),
          child: SizedBox(
            height: AmalfiSidebarMetrics.rowHeight,
            child: Padding(
              // With the eject button the row ends 8 after it (kit `Sidebars/Row/Volume`: the
              // 24 pt button at x 184 of the 216 row, the label 136 wide).
              padding: EdgeInsets.only(
                left: AmalfiSidebarMetrics.rowPadding,
                right: widget.trailing == null
                    ? AmalfiSidebarMetrics.rowPadding
                    : ejectTrailingPad,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: AmalfiSidebarMetrics.icon,
                    child: Center(child: widget.leading),
                  ),
                  const SizedBox(width: AmalfiSidebarMetrics.iconGap),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (widget.trailing case final trailing?) ...[
                    const SizedBox(width: ejectGap),
                    _RowHover(hovered: _hovered, child: trailing),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The eject button of a volume row (kit `Sidebars/Row/Volume`): a 24 pt hit area, 8 after the
/// label and 8 before the row's end, with the `eject` glyph 16 in `Text/Secondary` (also when
/// the row is selected); always visible.
const double ejectButton = 24;
const double ejectGlyph = 16;
const double ejectGap = 8;
const double ejectTrailingPad = 8;

/// Tells the eject button whether its row is hovered (it then draws the hover circle).
class _RowHover extends InheritedWidget {
  const _RowHover({required this.hovered, required super.child});

  final bool hovered;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowHover>()?.hovered ?? false;

  @override
  bool updateShouldNotify(_RowHover old) => old.hovered != hovered;
}

class EjectButton extends StatelessWidget {
  const EjectButton({super.key, required this.volume, required this.onPressed});

  /// The volume's name, for the screen reader ("Eject <volume>").
  final String volume;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final hovered = _RowHover.of(context);
    return Semantics(
      container: true,
      button: true,
      label: l10n.ejectVolume(volume),
      excludeSemantics: true,
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: ejectButton,
            child: DecoratedBox(
              // In the row's hover, a circle in the row's hover fill behind the glyph.
              decoration: BoxDecoration(
                color: hovered ? colors.lineSeparator : null,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AmalfiSymbol(
                  'eject',
                  size: ejectGlyph,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The right edge of the sidebar: dragging it changes the width (double arrow, also at the
/// minimum).
class SidebarDivider extends StatelessWidget {
  const SidebarDivider({
    super.key,
    required this.onDrag,
    required this.onRelease,
  });

  /// The pointer x in the window.
  final ValueChanged<double> onDrag;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeLeftRight,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => onDrag(d.globalPosition.dx),
      onHorizontalDragEnd: (_) => onRelease(),
      onHorizontalDragCancel: onRelease,
    ),
  );
}
