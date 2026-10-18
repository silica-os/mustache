// The app's menus in Silica's global menu bar (silica-menu-v1, silica_ui `SilicaMenuBar`;
// docs/spec/menus-and-settings.md › App menus and commands). One builder for the three places
// that publish them: the window, the desktop and the Open/Save dialog. Every state shows the same
// items; what a state cannot do has no action and the bar shows the item disabled.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';

/// The views of the View menu (⌘1–⌘4), in the order of the menu.
const List<ViewMode> menuViews = [
  ViewMode.icons,
  ViewMode.list,
  ViewMode.columns,
  ViewMode.gallery,
];

/// The folders the Go menu reaches by name.
enum GoPlace { documents, desktop, downloads, home, computer }

/// What the menus show and run. A null action leaves its item disabled (as a menu does for
/// something the state cannot do); the selection fills the names inside the labels.
class MenuSpec {
  const MenuSpec({
    this.selectionName,
    this.selectionCount = 0,
    this.selectionIsFolder = false,
    this.inTrash = false,
    this.editingText = false,
    this.newWindow,
    this.newFolder,
    this.newTab,
    this.open,
    this.openWith = const [],
    this.closeWindow,
    this.getInfo,
    this.rename,
    this.duplicate,
    this.quickLook,
    this.moveToTrash,
    this.emptyTrash,
    this.undo,
    this.undoLabel,
    this.redo,
    this.redoLabel,
    this.copy,
    this.cut,
    this.makeLink,
    this.showOriginal,
    this.paste,
    this.pasteCount = 0,
    this.selectAll,
    this.find,
    this.goToFolder,
    this.recents,
    this.settings,
    this.view,
    this.setView,
    this.galleryEnabled = true,
    this.useStacks = false,
    this.stacksOn = false,
    this.toggleStacks,
    this.sortChecked,
    this.sortBy,
    this.sortNone,
    this.snapToGrid,
    this.snapChecked = false,
    this.cleanUp,
    this.cleanUpBy,
    this.sidebarShown = true,
    this.toggleSidebar,
    this.previewShown = false,
    this.togglePreview,
    this.pathBarShown = false,
    this.togglePathBar,
    this.statusBarShown = false,
    this.toggleStatusBar,
    this.back,
    this.forward,
    this.enclosing,
    this.goTo,
    this.places = const {},
    this.previousTab,
    this.nextTab,
  });

  /// The name of the one selected item (for the labels), how many are selected, whether the one
  /// item is a folder, and whether the window shows the Trash.
  final String? selectionName;
  final int selectionCount;
  final bool selectionIsFolder;
  final bool inTrash;

  /// A text field has the keyboard (rename, search, the file name of Save): Edit acts on it.
  final bool editingText;

  // File.
  final VoidCallback? newWindow;
  final VoidCallback? newFolder;
  final VoidCallback? newTab;
  final VoidCallback? open;

  /// The items of Open With › (empty: the submenu is disabled).
  final List<PlatformMenuItem> openWith;
  final VoidCallback? closeWindow;
  final VoidCallback? getInfo;
  final VoidCallback? rename;
  final VoidCallback? duplicate;
  final VoidCallback? quickLook;
  final VoidCallback? moveToTrash;
  final VoidCallback? emptyTrash;

  // Edit.
  final VoidCallback? undo;
  final String? undoLabel;
  final VoidCallback? redo;
  final String? redoLabel;
  final VoidCallback? copy;
  final VoidCallback? cut;
  final VoidCallback? makeLink;
  final VoidCallback? showOriginal;
  final VoidCallback? paste;
  final int pasteCount;
  final VoidCallback? selectAll;
  final VoidCallback? find;

  /// Go › Go to Folder… (⇧⌘G).
  final VoidCallback? goToFolder;

  /// Go › Recents (⇧⌘F): the recently used files.
  final VoidCallback? recents;

  /// App › Settings… (⌘,).
  final VoidCallback? settings;

  // View.
  final ViewMode? view;

  /// Null on the desktop: the four views are disabled.
  final ValueChanged<ViewMode>? setView;
  final bool galleryEnabled;

  /// On the desktop the grouping item is "Use Stacks"; [toggleStacks] runs it.
  final bool useStacks;
  final bool stacksOn;
  final VoidCallback? toggleStacks;

  /// The checked order of Sort By ('none', 'name', 'kind', 'modified', 'size'), the function
  /// that chooses one and the ones for None and Snap to Grid (icon view only).
  final String? sortChecked;
  final ValueChanged<String>? sortBy;
  final VoidCallback? sortNone;
  final VoidCallback? snapToGrid;
  final bool snapChecked;
  final VoidCallback? cleanUp;
  final ValueChanged<String>? cleanUpBy;

  final bool sidebarShown;
  final VoidCallback? toggleSidebar;
  final bool previewShown;
  final VoidCallback? togglePreview;
  final bool pathBarShown;
  final VoidCallback? togglePathBar;
  final bool statusBarShown;
  final VoidCallback? toggleStatusBar;

  // Go.
  final VoidCallback? back;
  final VoidCallback? forward;
  final VoidCallback? enclosing;
  final ValueChanged<String>? goTo;
  final Map<GoPlace, String> places;

  // Window.
  final VoidCallback? previousTab;
  final VoidCallback? nextTab;
}

SingleActivator _cmd(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
  bool control = false,
}) =>
    SingleActivator(key, meta: true, shift: shift, alt: alt, control: control);

SilicaMenuItem _item(
  String label,
  VoidCallback? action, {
  SingleActivator? key,
  bool checked = false,
  SilicaMenuItemRole role = SilicaMenuItemRole.none,
}) => SilicaMenuItem(
  label: label,
  shortcut: key,
  onSelected: action,
  enabled: action != null,
  checked: checked,
  role: role,
);

PlatformMenuItemGroup _group(List<PlatformMenuItem> members) =>
    PlatformMenuItemGroup(members: members);

/// The four menus of a state, in the order of the bar: the app menu, File, Edit, View, Go,
/// Window, Help. Mustache keeps running without a window and has no Quit (DOCK-02): the app menu
/// has no Quit item.
List<PlatformMenuItem> buildMenus(MenuSpec s) => [
  _appMenu(s),
  _fileMenu(s),
  _editMenu(s),
  _viewMenu(s),
  _goMenu(s),
  _windowMenu(s),
  // Help is silica_ui's standard menu (silica-ui#99).
];

/// The name of the app in the bar (not translated).
const String appName = 'Mustache';

/// silica_ui's standard app menu (silica-ui#99): About Mustache (the standard About panel),
/// Settings… while there is a settings window to open, Empty Trash…, the system items; no Quit,
/// as Mustache has none (`SilicaApp.quitEnabled`).
SilicaMenu _appMenu(MenuSpec s) => SilicaMenus.app(
  appName,
  onSettings: s.settings,
  items: [
    _group([
      _item(
        l10n.menuEmptyTrash,
        s.emptyTrash,
        key: _cmd(LogicalKeyboardKey.backspace, shift: true),
      ),
    ]),
  ],
);

SilicaMenu _fileMenu(MenuSpec s) {
  final name = s.selectionName;
  final one = s.selectionCount == 1 && name != null;
  return SilicaMenu(
    label: l10n.menuFile,
    menus: [
      _group([
        _item(
          l10n.menuNewWindow,
          s.newWindow,
          key: _cmd(LogicalKeyboardKey.keyN),
        ),
        _item(
          l10n.newFolder,
          s.newFolder,
          key: _cmd(LogicalKeyboardKey.keyN, shift: true),
        ),
        // New Folder with Selection is not done yet; the label follows the selection.
        _item(
          one
              ? l10n.menuNewFolderWith(l10n.quoted(name))
              : s.selectionCount > 1
              ? l10n.newFolderWithSelection(s.selectionCount)
              : l10n.menuNewFolderWithSelection,
          null,
          key: _cmd(LogicalKeyboardKey.keyN, control: true),
        ),
        _item(l10n.menuNewSmartFolder, null),
        _item(l10n.menuNewTab, s.newTab, key: _cmd(LogicalKeyboardKey.keyT)),
        _item(l10n.open, s.open, key: _cmd(LogicalKeyboardKey.keyO)),
        SilicaMenu(
          label: l10n.openWith,
          enabled: s.openWith.isNotEmpty,
          menus: s.openWith,
        ),
        _item(
          l10n.menuCloseWindow,
          s.closeWindow,
          key: _cmd(LogicalKeyboardKey.keyW),
        ),
      ]),
      _group([
        _item(l10n.menuGetInfo, s.getInfo, key: _cmd(LogicalKeyboardKey.keyI)),
        _item(l10n.rename, s.rename),
        _item(l10n.menuCompress, null),
        _item(l10n.duplicate, s.duplicate, key: _cmd(LogicalKeyboardKey.keyD)),
        _item(
          l10n.menuMakeLink,
          s.makeLink,
          key: _cmd(LogicalKeyboardKey.keyA, control: true),
        ),
        _item(
          l10n.menuQuickLook,
          s.quickLook,
          key: _cmd(LogicalKeyboardKey.keyY),
        ),
      ]),
      _group([
        _item(l10n.menuShare, null),
        _item(
          s.selectionCount == 1 && !s.selectionIsFolder
              ? l10n.menuManageSharedFile
              : l10n.menuManageSharedFolder,
          null,
        ),
      ]),
      _group([
        _item(
          l10n.menuShowOriginal,
          s.showOriginal,
          key: _cmd(LogicalKeyboardKey.keyR),
        ),
        _item(
          l10n.menuAddToSidebar,
          null,
          key: _cmd(LogicalKeyboardKey.keyT, control: true),
        ),
      ]),
      _group([
        _item(
          s.inTrash ? l10n.restore : l10n.moveToTrash,
          s.moveToTrash,
          key: _cmd(LogicalKeyboardKey.backspace),
        ),
        _item(l10n.menuEject, null, key: _cmd(LogicalKeyboardKey.keyE)),
      ]),
      _group([_item(l10n.menuPrint, null, key: _cmd(LogicalKeyboardKey.keyP))]),
    ],
  );
}

SilicaMenu _editMenu(MenuSpec s) {
  final find = _item(l10n.menuFind, s.find, key: _cmd(LogicalKeyboardKey.keyF));
  // In a text field the standard items act on the field.
  if (s.editingText) {
    return SilicaMenus.textEdit(l10n.menuEdit, items: [find]);
  }
  final name = s.selectionName;
  return SilicaMenu(
    label: l10n.menuEdit,
    menus: [
      _group([
        _item(
          s.undoLabel ?? l10n.menuUndo,
          s.undo,
          key: _cmd(LogicalKeyboardKey.keyZ),
          role: SilicaMenuItemRole.undo,
        ),
        _item(
          s.redoLabel ?? l10n.menuRedo,
          s.redo,
          key: _cmd(LogicalKeyboardKey.keyZ, shift: true),
          role: SilicaMenuItemRole.redo,
        ),
      ]),
      _group([
        _item(
          l10n.menuCut,
          s.cut,
          key: _cmd(LogicalKeyboardKey.keyX),
          role: SilicaMenuItemRole.cut,
        ),
        _item(
          s.selectionCount == 1 && name != null
              ? l10n.menuCopyName(l10n.quoted(name))
              : s.selectionCount > 1
              ? l10n.menuCopyItems(s.selectionCount)
              : l10n.copy,
          s.copy,
          key: _cmd(LogicalKeyboardKey.keyC),
          role: SilicaMenuItemRole.copy,
        ),
        _item(
          l10n.pasteItems(s.pasteCount),
          s.paste,
          key: _cmd(LogicalKeyboardKey.keyV),
          role: SilicaMenuItemRole.paste,
        ),
        _item(
          l10n.menuSelectAll,
          s.selectAll,
          key: _cmd(LogicalKeyboardKey.keyA),
          role: SilicaMenuItemRole.selectAll,
        ),
      ]),
      _group([_item(l10n.menuShowClipboard, null)]),
      _group([find]),
    ],
  );
}

SilicaMenu _viewMenu(MenuSpec s) {
  final setView = s.setView;
  SilicaMenuItem mode(ViewMode m, String label, LogicalKeyboardKey key) =>
      _item(
        label,
        setView == null || (m == ViewMode.gallery && !s.galleryEnabled)
            ? null
            : () => setView(m),
        key: _cmd(key),
        checked: s.view == m,
      );
  final sortBy = s.sortBy;
  SilicaMenuItem sort(String key, String label, LogicalKeyboardKey digit) =>
      _item(
        label,
        sortBy == null ? null : () => sortBy(key),
        key: _cmd(digit, control: true, alt: true),
        checked: s.sortChecked == key,
      );
  SilicaMenuItem unsorted(String label, LogicalKeyboardKey? digit) => _item(
    label,
    null,
    key: digit == null ? null : _cmd(digit, control: true, alt: true),
  );
  final cleanUpBy = s.cleanUpBy;
  SilicaMenuItem arrange(String key, String label, LogicalKeyboardKey digit) =>
      _item(
        label,
        cleanUpBy == null ? null : () => cleanUpBy(key),
        key: _cmd(digit, alt: true),
      );
  SilicaMenuItem unarranged(String label, LogicalKeyboardKey? digit) =>
      _item(label, null, key: digit == null ? null : _cmd(digit, alt: true));
  return SilicaMenu(
    label: l10n.view,
    menus: [
      _group([
        mode(ViewMode.icons, l10n.menuAsIcons, LogicalKeyboardKey.digit1),
        mode(ViewMode.list, l10n.menuAsList, LogicalKeyboardKey.digit2),
        mode(ViewMode.columns, l10n.menuAsColumns, LogicalKeyboardKey.digit3),
        mode(ViewMode.gallery, l10n.menuAsGallery, LogicalKeyboardKey.digit4),
      ]),
      _group([
        _item(
          s.useStacks ? l10n.menuUseStacks : l10n.menuUseGroups,
          s.toggleStacks,
          key: _cmd(LogicalKeyboardKey.digit0, control: true),
          checked: s.useStacks && s.stacksOn,
        ),
        SilicaMenu(
          label: l10n.sortBy,
          enabled: sortBy != null,
          menus: [
            _group([
              _item(
                l10n.sortNone,
                s.sortNone,
                key: _cmd(LogicalKeyboardKey.digit0, control: true, alt: true),
                checked: s.sortChecked == 'none',
              ),
            ]),
            _group([
              _item(
                l10n.snapToGrid,
                s.snapToGrid,
                checked: s.snapChecked && s.snapToGrid != null,
              ),
            ]),
            _group([
              sort('name', l10n.sortName, LogicalKeyboardKey.digit1),
              sort('kind', l10n.sortKind, LogicalKeyboardKey.digit2),
              unsorted(l10n.menuSortLastOpened, LogicalKeyboardKey.digit3),
              unsorted(l10n.menuSortAdded, LogicalKeyboardKey.digit4),
              sort('modified', l10n.sortModified, LogicalKeyboardKey.digit5),
              unsorted(l10n.menuSortCreated, null),
              sort('size', l10n.sortSize, LogicalKeyboardKey.digit6),
              unsorted(l10n.menuSortTags, LogicalKeyboardKey.digit7),
            ]),
          ],
        ),
        _item(l10n.cleanUp, s.cleanUp),
        SilicaMenu(
          label: l10n.cleanUpBy,
          enabled: cleanUpBy != null,
          menus: [
            arrange('name', l10n.sortName, LogicalKeyboardKey.digit1),
            arrange('kind', l10n.sortKind, LogicalKeyboardKey.digit2),
            arrange('modified', l10n.sortModified, LogicalKeyboardKey.digit5),
            unarranged(l10n.menuSortCreated, null),
            arrange('size', l10n.sortSize, LogicalKeyboardKey.digit6),
            unarranged(l10n.menuSortTags, LogicalKeyboardKey.digit7),
          ],
        ),
      ]),
      _group([
        // The tab bar shows by itself with two tabs: there is no switch for it.
        _item(
          l10n.menuShowTabBar,
          null,
          key: _cmd(LogicalKeyboardKey.keyT, shift: true),
        ),
        _item(
          l10n.menuShowAllTabs,
          null,
          key: _cmd(LogicalKeyboardKey.backslash, shift: true),
        ),
      ]),
      _group([
        _item(
          s.sidebarShown ? l10n.menuHideSidebar : l10n.menuShowSidebar,
          s.toggleSidebar,
          key: _cmd(LogicalKeyboardKey.keyS, control: true),
        ),
        _item(
          s.previewShown ? l10n.menuHidePreview : l10n.menuShowPreview,
          s.togglePreview,
          key: _cmd(LogicalKeyboardKey.keyP, shift: true),
        ),
      ]),
      _group([
        _item(
          l10n.menuHideToolbar,
          null,
          key: _cmd(LogicalKeyboardKey.keyT, alt: true),
        ),
        _item(
          s.pathBarShown ? l10n.menuHidePathBar : l10n.menuShowPathBar,
          s.togglePathBar,
          key: _cmd(LogicalKeyboardKey.keyP, alt: true),
        ),
        _item(
          s.statusBarShown ? l10n.menuHideStatusBar : l10n.menuShowStatusBar,
          s.toggleStatusBar,
          key: _cmd(LogicalKeyboardKey.quoteSingle),
        ),
      ]),
      _group([_item(l10n.menuCustomizeToolbar, null)]),
      _group([
        _item(
          l10n.menuShowViewOptions,
          null,
          key: _cmd(LogicalKeyboardKey.keyJ),
        ),
        _item(l10n.menuShowPreviewOptions, null),
      ]),
      _group([const SilicaMenuItem.system(SilicaMenuItemRole.fullScreen)]),
    ],
  );
}

SilicaMenu _goMenu(MenuSpec s) {
  final goTo = s.goTo;
  SilicaMenuItem place(GoPlace p, String label, SingleActivator key) {
    final path = s.places[p];
    return _item(
      label,
      goTo == null || path == null ? null : () => goTo(path),
      key: key,
    );
  }

  return SilicaMenu(
    label: l10n.menuGo,
    menus: [
      _group([
        _item(l10n.menuBack, s.back, key: _cmd(LogicalKeyboardKey.bracketLeft)),
        _item(
          l10n.menuForward,
          s.forward,
          key: _cmd(LogicalKeyboardKey.bracketRight),
        ),
        _item(
          l10n.menuEnclosingFolder,
          s.enclosing,
          key: _cmd(LogicalKeyboardKey.arrowUp),
        ),
      ]),
      _group([
        _item(
          l10n.menuRecents,
          s.recents,
          key: _cmd(LogicalKeyboardKey.keyF, shift: true),
        ),
        place(
          GoPlace.documents,
          l10n.menuDocuments,
          _cmd(LogicalKeyboardKey.keyO, shift: true),
        ),
        place(
          GoPlace.desktop,
          l10n.menuDesktop,
          _cmd(LogicalKeyboardKey.keyD, shift: true),
        ),
        place(
          GoPlace.downloads,
          l10n.menuDownloads,
          _cmd(LogicalKeyboardKey.keyL, alt: true),
        ),
        place(
          GoPlace.home,
          l10n.menuHome,
          _cmd(LogicalKeyboardKey.keyH, shift: true),
        ),
        place(
          GoPlace.computer,
          l10n.menuComputer,
          _cmd(LogicalKeyboardKey.keyC, shift: true),
        ),
        _item(
          l10n.menuNearbySharing,
          null,
          key: _cmd(LogicalKeyboardKey.keyR, shift: true),
        ),
        _item(
          l10n.menuNetwork,
          null,
          key: _cmd(LogicalKeyboardKey.keyK, shift: true),
        ),
        _item(
          l10n.menuCloudDrive,
          null,
          key: _cmd(LogicalKeyboardKey.keyI, shift: true),
        ),
        _item(
          l10n.menuShared,
          null,
          key: _cmd(LogicalKeyboardKey.keyS, shift: true),
        ),
        _item(
          l10n.menuApplications,
          null,
          key: _cmd(LogicalKeyboardKey.keyA, shift: true),
        ),
        _item(
          l10n.menuUtilities,
          null,
          key: _cmd(LogicalKeyboardKey.keyU, shift: true),
        ),
      ]),
      _group([
        SilicaMenu(label: l10n.menuRecentFolders, enabled: false, menus: []),
      ]),
      _group([
        _item(
          l10n.menuGoToFolder,
          s.goToFolder,
          key: _cmd(LogicalKeyboardKey.keyG, shift: true),
        ),
        _item(
          l10n.menuConnectToServer,
          null,
          key: _cmd(LogicalKeyboardKey.keyK),
        ),
      ]),
    ],
  );
}

/// Window: the tab items come first, the bar adds Minimize, Fill, Move & Resize, Full screen,
/// Bring All to Front and the list of the windows after them.
SilicaMenu _windowMenu(MenuSpec s) => SilicaMenus.window(
  l10n.menuWindow,
  items: [
    _group([
      _item(
        l10n.menuPreviousTab,
        s.previousTab,
        key: const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ),
      ),
      _item(
        l10n.menuNextTab,
        s.nextTab,
        key: const SingleActivator(LogicalKeyboardKey.tab, control: true),
      ),
      _item(l10n.menuMoveTabToWindow, null),
      _item(l10n.menuMergeWindows, null),
    ]),
    _group([_item(l10n.menuShowProgress, null)]),
  ],
);

/// A text that changes whenever what the bar shows changes: labels, enabled states,
/// checkmarks and shortcuts, not the actions (those read the state when they run).
String menuSignature(List<PlatformMenuItem> menus) {
  final out = StringBuffer();
  void walk(List<PlatformMenuItem> items) {
    for (final item in items) {
      switch (item) {
        case PlatformMenuItemGroup(:final members):
          out.write('|');
          walk(members);
          out.write('|');
        case PlatformMenu(:final label, :final menus):
          final on = item is! SilicaMenu || item.enabled;
          out.write('$label${on ? '' : '!'}[');
          walk(menus);
          out.write(']');
        default:
          final silica = item is SilicaMenuItem ? item : null;
          final on = (silica?.enabled ?? true) && (silica?.hasAction ?? true);
          final shortcut = silicaMenuShortcut(item.shortcut);
          out.write(
            '${item.label}${on ? '' : '!'}${silica?.checked ?? false ? '+' : ''}'
            '${silica?.role.wire ?? ''}${shortcut ?? ''};',
          );
      }
    }
  }

  walk(menus);
  return out.toString();
}
