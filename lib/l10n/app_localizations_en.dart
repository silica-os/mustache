// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get open => 'Open';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get replace => 'Replace';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get openWith => 'Open With';

  @override
  String get showInfo => 'Show Info';

  @override
  String get rename => 'Rename';

  @override
  String get renameMany => 'Rename…';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get copy => 'Copy';

  @override
  String get tagsMenu => 'Tags…';

  @override
  String get moveToTrash => 'Move to Trash';

  @override
  String get restore => 'Restore';

  @override
  String newFolderWithSelection(int count) {
    return 'New Folder from Selection ($count items)';
  }

  @override
  String defaultApp(String app) {
    return '$app (default)';
  }

  @override
  String get otherApp => 'Other…';

  @override
  String get newFolder => 'New Folder';

  @override
  String pasteItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Paste $count Items',
      one: 'Paste Item',
      zero: 'Paste Item',
    );
    return '$_temp0';
  }

  @override
  String get view => 'View';

  @override
  String get viewIcons => 'Icons';

  @override
  String get viewList => 'List';

  @override
  String get viewColumns => 'Columns';

  @override
  String get viewGallery => 'Gallery';

  @override
  String get sortBy => 'Sort By';

  @override
  String get sortName => 'Name';

  @override
  String get sortKind => 'Type';

  @override
  String get sortModified => 'Modified';

  @override
  String get sortSize => 'Size';

  @override
  String get sortNone => 'None';

  @override
  String get snapToGrid => 'Snap to Grid';

  @override
  String get cleanUp => 'Clean Up';

  @override
  String get cleanUpSelection => 'Clean Up Selection';

  @override
  String get cleanUpBy => 'Clean Up By';

  @override
  String get columnName => 'Name';

  @override
  String get columnModified => 'Date Modified';

  @override
  String get columnSize => 'Size';

  @override
  String get columnKind => 'Kind';

  @override
  String get sidebarPinned => 'Pinned';

  @override
  String get sidebarPlaces => 'Places';

  @override
  String get sidebarTags => 'Tags';

  @override
  String get trash => 'Trash';

  @override
  String get disk => 'Disk';

  @override
  String get tagRed => 'Red';

  @override
  String get tagOrange => 'Orange';

  @override
  String get tagYellow => 'Yellow';

  @override
  String get tagGreen => 'Green';

  @override
  String get tagBlue => 'Blue';

  @override
  String get tagPurple => 'Purple';

  @override
  String get tagGray => 'Gray';

  @override
  String get tagError => 'Can\'t assign the tag.';

  @override
  String get tagErrorDetail => 'The disk does not support extended attributes.';

  @override
  String get addTag => 'Add a tag…';

  @override
  String get paneEdit => 'Edit';

  @override
  String get shareLabel => 'Share';

  @override
  String get shareCopy => 'Copy';

  @override
  String get paneMore => 'More';

  @override
  String get sizeZero => 'Zero bytes';

  @override
  String sizeBytes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bytes',
      one: '1 byte',
    );
    return '$_temp0';
  }

  @override
  String get decimalSeparator => '.';

  @override
  String get monthsShort => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String get monthsLong =>
      'January,February,March,April,May,June,July,August,September,October,November,December';

  @override
  String dateToday(String time) {
    return 'Today, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'Yesterday, $time';
  }

  @override
  String dateShort(String day, String month, String year, String time) {
    return '$month $day, $year, $time';
  }

  @override
  String dateLong(String day, String month, String year, String time) {
    return '$month $day, $year, $time';
  }

  @override
  String get kindLink => 'Link';

  @override
  String get kindFolder => 'Folder';

  @override
  String kindImage(String format) {
    return '$format image';
  }

  @override
  String kindAudio(String format) {
    return '$format audio';
  }

  @override
  String get kindVideo => 'Video';

  @override
  String get kindArchive => 'Archive';

  @override
  String kindArchiveExt(String ext) {
    return '$ext archive';
  }

  @override
  String get kindText => 'Text';

  @override
  String get kindDocument => 'Document';

  @override
  String get newFolderName => 'new folder';

  @override
  String copySuffix(String base) {
    return '$base copy';
  }

  @override
  String linkSuffix(String base) {
    return '$base link';
  }

  @override
  String get opMakeLink => 'Make Link';

  @override
  String opMakeLinkMany(int count) {
    return 'Make $count links';
  }

  @override
  String get cantMakeLink => 'Can\'t make a link.';

  @override
  String get cantShowOriginal => 'Can\'t show the original.';

  @override
  String get errorGone => 'The item no longer exists.';

  @override
  String errorNameInvalid(String name) {
    return 'The name “$name” can\'t be used. Choose another name.';
  }

  @override
  String errorNameSlash(String name) {
    return 'The name “$name” can\'t be used. Try a name without the slash “/”.';
  }

  @override
  String errorNameTaken(String name) {
    return 'The name “$name” is already taken. Choose another one.';
  }

  @override
  String errorUnknownOrigin(String name) {
    return 'It is not known where “$name” came from.';
  }

  @override
  String errorOriginTaken(String name) {
    return 'The original folder already has an item named “$name”.';
  }

  @override
  String get errorPermission =>
      'You don\'t have permission for this operation.';

  @override
  String get errorDiskFull => 'The disk is full.';

  @override
  String get errorReadOnly => 'The disk is read-only.';

  @override
  String get errorFolderIntoItself => 'A folder can\'t be put inside itself.';

  @override
  String errorAlreadyExists(String name) {
    return 'There is already an item named “$name”.';
  }

  @override
  String get opMove => 'Move';

  @override
  String undoAction(String action) {
    return 'Undo $action';
  }

  @override
  String redoAction(String action) {
    return 'Redo $action';
  }

  @override
  String get opDuplicate => 'Duplicate';

  @override
  String opDuplicateMany(int count) {
    return 'Duplicate $count items';
  }

  @override
  String get unknownCopy => 'Unknown copy';

  @override
  String get copyCantRedo => 'The copy can\'t be redone.';

  @override
  String get cantRename => 'Can\'t rename.';

  @override
  String cantRenameItem(String name) {
    return 'Can\'t rename “$name”.';
  }

  @override
  String get cantCreateFolder => 'Can\'t create the folder.';

  @override
  String get cantDuplicate => 'Can\'t duplicate.';

  @override
  String get cantTrash => 'Can\'t move to the Trash.';

  @override
  String get cantRestore => 'Can\'t restore.';

  @override
  String get cantDelete => 'Can\'t delete.';

  @override
  String get cantUndo => 'Can\'t undo.';

  @override
  String get cantRedo => 'Can\'t redo.';

  @override
  String get cantCopy => 'Can\'t complete the copy.';

  @override
  String get cantMove => 'Can\'t complete the move.';

  @override
  String cantOpenFolder(String error) {
    return 'Can\'t open: $error';
  }

  @override
  String get cantOpenWindow => 'Can\'t open a new window.';

  @override
  String get entryNotInstalled =>
      'The Mustache desktop entry is not installed (cargo xtask install-app).';

  @override
  String extensionRemove(String old) {
    return 'Remove the extension “$old”?';
  }

  @override
  String extensionChange(String newExt, String old) {
    return 'Use the extension “$newExt” instead of “$old”?';
  }

  @override
  String get extensionWarning =>
      'With another extension the file may open in a different app.';

  @override
  String keepExtension(String ext) {
    return 'Keep $ext';
  }

  @override
  String get removeExtension => 'Remove';

  @override
  String useExtension(String ext) {
    return 'Use $ext';
  }

  @override
  String confirmDeleteOne(String name) {
    return 'Delete “$name” permanently?';
  }

  @override
  String confirmDeleteMany(int count) {
    return 'Delete $count items permanently?';
  }

  @override
  String get deleteWarningOne =>
      'This item will be deleted right away. This can\'t be undone.';

  @override
  String get deleteWarningMany =>
      'These items will be deleted right away. This can\'t be undone.';

  @override
  String appHasNoCommand(String app) {
    return 'The entry of “$app” has no command.';
  }

  @override
  String appCantOpen(String app, String error) {
    return 'Can\'t open “$app”: $error';
  }

  @override
  String replaceQuestion(String name) {
    return 'Replace “$name”?';
  }

  @override
  String get replaceDetail =>
      'An item with this name already exists in this folder.';

  @override
  String get saveAs => 'Save as:';

  @override
  String get searchIn => 'Search in:';

  @override
  String get thisComputer => 'This Computer';

  @override
  String searchTitle(String scope) {
    return 'Searching “$scope”';
  }

  @override
  String quoted(String name) {
    return '“$name”';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String selectedCount(int selected, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$selected of $count selected',
      one: '$selected of 1 selected',
    );
    return '$_temp0';
  }

  @override
  String available(String head, String free) {
    return '$head, $free available';
  }

  @override
  String documentsSize(int count, String size) {
    return '$count documents - $size';
  }

  @override
  String get information => 'Information';

  @override
  String get created => 'Created';

  @override
  String get modified => 'Modified';

  @override
  String get size => 'Size';

  @override
  String get tags => 'Tags';

  @override
  String get infoGeneral => 'General';

  @override
  String get infoMoreInfo => 'More Info';

  @override
  String get infoContentType => 'Content type';

  @override
  String get infoDimensions => 'Dimensions';

  @override
  String infoPixels(int width, int height) {
    return '$width × $height pixels';
  }

  @override
  String get infoLastOpened => 'Last opened';

  @override
  String get infoNameExtension => 'Name and Extension';

  @override
  String get infoComments => 'Comments';

  @override
  String get infoPreview => 'Preview';

  @override
  String get infoPermissions => 'Sharing and Permissions';

  @override
  String get privilegeReadWrite => 'Read and write';

  @override
  String get privilegeReadOnly => 'Read only';

  @override
  String get privilegeWriteOnly => 'Write only';

  @override
  String get privilegeNone => 'No access';

  @override
  String infoTitle(String name) {
    return '$name Info';
  }

  @override
  String modifiedOn(String date) {
    return 'Modified: $date';
  }

  @override
  String get kind => 'Type';

  @override
  String sizeOnDisk(int bytes, String disk) {
    return '$bytes bytes ($disk on disk)';
  }

  @override
  String get location => 'Location';

  @override
  String get app => 'App';

  @override
  String get none => 'None';

  @override
  String get groupFallback => 'group';

  @override
  String get everyone => 'everyone';

  @override
  String ownerMe(String owner) {
    return '$owner (me)';
  }

  @override
  String positionOf(String name, int index, int count) {
    return '$name  ($index of $count)';
  }

  @override
  String openWithApp(String app) {
    return 'Open with $app';
  }

  @override
  String lastModified(String date) {
    return 'Last modified: $date';
  }

  @override
  String get copying => 'Copying';

  @override
  String get moving => 'Moving';

  @override
  String transferLine(String verb, String name, String destination) {
    return '$verb “$name” to “$destination”';
  }

  @override
  String progressOf(String done, String total) {
    return '$done of $total';
  }

  @override
  String conflictCopy(String name) {
    return 'An item named “$name” already exists here. Replace it with the one you are copying?';
  }

  @override
  String conflictMove(String name) {
    return 'An item named “$name” already exists here. Replace it with the one you are moving?';
  }

  @override
  String get keepBoth => 'Keep both';

  @override
  String get stop => 'Stop';

  @override
  String get customizeFolder => 'Customize Folder…';

  @override
  String get folderNoSymbols => 'No symbols';

  @override
  String get folderStyleError => 'This folder can\'t be customized.';

  @override
  String get folderRemoveAllTags => 'Remove all tags';

  @override
  String get folderAddTag => 'Add tag';

  @override
  String get folderEditTags => 'Edit Tags…';

  @override
  String get folderClear => 'Clear';

  @override
  String get folderEmoji => 'Emoji';

  @override
  String get emojiSearch => 'Search';

  @override
  String get emojiNone => 'No emoji found';

  @override
  String get symbolPeople => 'People';

  @override
  String get symbolNature => 'Animals & Nature';

  @override
  String get symbolFood => 'Food & Drink';

  @override
  String get symbolActivities => 'Activities';

  @override
  String get symbolTravel => 'Travel & Places';

  @override
  String get symbolObjects => 'Objects';

  @override
  String get symbolSymbols => 'Symbols';

  @override
  String get emojiFrequent => 'Frequently Used';

  @override
  String get emojiSmileys => 'Smileys & People';

  @override
  String get emojiAnimals => 'Animals & Nature';

  @override
  String get emojiFood => 'Food & Drink';

  @override
  String get emojiActivity => 'Activity';

  @override
  String get emojiTravel => 'Travel & Places';

  @override
  String get emojiObjects => 'Objects';

  @override
  String get emojiSymbols => 'Symbols';

  @override
  String get emojiFlags => 'Flags';

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuGo => 'Go';

  @override
  String get menuWindow => 'Window';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuEmptyTrashAction => 'Empty Trash';

  @override
  String get confirmEmptyTrash =>
      'Are you sure you want to permanently erase the items in the Trash?';

  @override
  String get emptyTrashWarning => 'You can’t undo this action.';

  @override
  String get menuEmptyTrash => 'Empty Trash…';

  @override
  String get menuNewWindow => 'New Mustache Window';

  @override
  String menuNewFolderWith(String name) {
    return 'New Folder with $name';
  }

  @override
  String get menuNewFolderWithSelection => 'New Folder with Selection';

  @override
  String get menuNewSmartFolder => 'New Smart Folder';

  @override
  String get menuNewTab => 'New Tab';

  @override
  String get menuCloseWindow => 'Close Window';

  @override
  String get menuGetInfo => 'Get Info';

  @override
  String get menuCompress => 'Compress';

  @override
  String get menuMakeLink => 'Make Link';

  @override
  String get menuQuickLook => 'Quick Look';

  @override
  String get menuShare => 'Share…';

  @override
  String get menuManageSharedFolder => 'Manage Shared Folder…';

  @override
  String get menuManageSharedFile => 'Manage Shared File…';

  @override
  String get menuShowOriginal => 'Show Original';

  @override
  String get menuAddToSidebar => 'Add to Sidebar';

  @override
  String get menuEject => 'Eject';

  @override
  String get menuPrint => 'Print';

  @override
  String get menuUndo => 'Undo';

  @override
  String get menuRedo => 'Redo';

  @override
  String get menuCut => 'Cut';

  @override
  String menuCopyName(String name) {
    return 'Copy $name';
  }

  @override
  String menuCopyItems(int count) {
    return 'Copy $count Items';
  }

  @override
  String get menuSelectAll => 'Select All';

  @override
  String get menuShowClipboard => 'Show Clipboard';

  @override
  String get menuFind => 'Find';

  @override
  String get menuAsIcons => 'as Icons';

  @override
  String get menuAsList => 'as List';

  @override
  String get menuAsColumns => 'as Columns';

  @override
  String get menuAsGallery => 'as Gallery';

  @override
  String get menuUseGroups => 'Use Groups';

  @override
  String get menuUseStacks => 'Use Stacks';

  @override
  String get menuSortLastOpened => 'Last Opened';

  @override
  String get menuSortAdded => 'Date Added';

  @override
  String get menuSortCreated => 'Created';

  @override
  String get menuSortTags => 'Tags';

  @override
  String get menuShowTabBar => 'Show Tab Bar';

  @override
  String get menuShowAllTabs => 'Show All Tabs';

  @override
  String get menuHideSidebar => 'Hide Sidebar';

  @override
  String get menuShowSidebar => 'Show Sidebar';

  @override
  String get menuShowPreview => 'Show Preview';

  @override
  String get menuHidePreview => 'Hide Preview';

  @override
  String get menuHideToolbar => 'Hide Toolbar';

  @override
  String get menuShowPathBar => 'Show Path Bar';

  @override
  String get menuHidePathBar => 'Hide Path Bar';

  @override
  String get menuShowStatusBar => 'Show Status Bar';

  @override
  String get menuHideStatusBar => 'Hide Status Bar';

  @override
  String get menuCustomizeToolbar => 'Customize Toolbar…';

  @override
  String get menuShowViewOptions => 'Show View Options';

  @override
  String get menuShowPreviewOptions => 'Show Preview Options';

  @override
  String get menuBack => 'Back';

  @override
  String get menuForward => 'Forward';

  @override
  String get menuEnclosingFolder => 'Enclosing Folder';

  @override
  String get menuRecents => 'Recents';

  @override
  String get menuDocuments => 'Documents';

  @override
  String get menuDesktop => 'Desktop';

  @override
  String get menuDownloads => 'Downloads';

  @override
  String get menuHome => 'Home';

  @override
  String get menuComputer => 'Computer';

  @override
  String get menuNearbySharing => 'Nearby Sharing';

  @override
  String get menuNetwork => 'Network';

  @override
  String get menuCloudDrive => 'Cloud Drive';

  @override
  String get menuShared => 'Shared';

  @override
  String get menuApplications => 'Applications';

  @override
  String get menuUtilities => 'Utilities';

  @override
  String get menuRecentFolders => 'Recent Folders';

  @override
  String get menuGoToFolder => 'Go to Folder…';

  @override
  String get menuConnectToServer => 'Connect to Server…';

  @override
  String get menuPreviousTab => 'Show Previous Tab';

  @override
  String get menuNextTab => 'Show Next Tab';

  @override
  String get menuMoveTabToWindow => 'Move Tab to New Window';

  @override
  String get menuMergeWindows => 'Merge All Windows';

  @override
  String get menuShowProgress => 'Show Progress Window';

  @override
  String get searchPlaceholder => 'Search';

  @override
  String get toggleSidebar => 'Sidebar';

  @override
  String get iconSize => 'Icon size';

  @override
  String get menuCloseTab => 'Close Tab';

  @override
  String get closeSheet => 'Close';

  @override
  String get goToFolderHeader => 'Go to:';

  @override
  String get goToFolderNotFound => 'Folder not found';

  @override
  String get saveSearchTitle => 'Save this search';

  @override
  String get saveSearchMessage => 'Name it and choose where to keep it.';

  @override
  String get saveSearchName => 'Save As:';

  @override
  String get saveSearchTags => 'Tags:';

  @override
  String get saveSearchWhere => 'Where:';

  @override
  String get saveSearchAddTags => 'Add tags';

  @override
  String get saveSearchAddToSidebar => 'Add to Sidebar';

  @override
  String get savedSearchesFolder => 'Saved Searches';

  @override
  String savedSearchNameInFolder(String folder, String query) {
    return '$folder named $query';
  }

  @override
  String savedSearchNameEverywhere(String query) {
    return 'Search for $query';
  }

  @override
  String get saveSearchError => 'The search could not be saved';

  @override
  String get saveSearchButton => 'Save';

  @override
  String savedSearchDamaged(String name) {
    return '“$name” is not a saved search.';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsTags => 'Tags';

  @override
  String get settingsSidebar => 'Sidebar';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsWindowsAndNames => 'Windows and names';

  @override
  String get settingsNewWindowsShow => 'New windows show';

  @override
  String get settingsOpenInTabs =>
      'Open folders in tabs instead of new windows';

  @override
  String get settingsHomeFolder => 'Home folder';

  @override
  String get settingsShowTags => 'Show these tags in the sidebar';

  @override
  String get settingsFavouriteTags => 'Favourite tags';

  @override
  String get settingsFavouritesCaption =>
      'Drag to reorder: the first seven appear in the context menu.';

  @override
  String get settingsColourFolders => 'Colour folders by tag';

  @override
  String get settingsConfirmBefore => 'Ask for confirmation before';

  @override
  String get settingsConfirmExtension => 'Changing a file extension';

  @override
  String get settingsConfirmTrash => 'Emptying the Trash';

  @override
  String get settingsTrashCleanup =>
      'Remove items from the Trash after 30 days';

  @override
  String get settingsFoldersOnTop => 'Keep folders on top';

  @override
  String get settingsFoldersOnTopWindows => 'In windows when sorting by name';

  @override
  String get settingsFoldersOnTopDesktop => 'On the desktop';

  @override
  String get settingsWhenSearching => 'When searching';

  @override
  String get settingsSearchIn => 'Search in';

  @override
  String get settingsCurrentFolder => 'Current folder';

  @override
  String get toolbarActions => 'Actions';

  @override
  String get toolbarTags => 'Tags';

  @override
  String get toolbarMore => 'More';

  @override
  String get tagsShowAll => 'Show All…';
}
