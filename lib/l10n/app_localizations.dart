import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// Opens the chosen items (menu item, dialog button).
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// Save dialog button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancels an alert or a dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Replaces an existing item.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// Acknowledges an error.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Deletes items permanently.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Submenu and Info section listing apps that open a file.
  ///
  /// In en, this message translates to:
  /// **'Open With'**
  String get openWith;

  /// Opens the Info window of the items.
  ///
  /// In en, this message translates to:
  /// **'Show Info'**
  String get showInfo;

  /// Renames one item; also the name of the undoable operation.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Renames several items (disabled).
  ///
  /// In en, this message translates to:
  /// **'Rename…'**
  String get renameMany;

  /// Makes copies next to the originals.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// Copies the items to the clipboard; also the name of the undoable copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Opens the tag editor (disabled).
  ///
  /// In en, this message translates to:
  /// **'Tags…'**
  String get tagsMenu;

  /// Moves items to the Trash.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get moveToTrash;

  /// Puts items in the Trash back where they were.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// Disabled item shown when several items are chosen.
  ///
  /// In en, this message translates to:
  /// **'New Folder from Selection ({count} items)'**
  String newFolderWithSelection(int count);

  /// The default app in the Open With submenu.
  ///
  /// In en, this message translates to:
  /// **'{app} (default)'**
  String defaultApp(String app);

  /// Chooses another app (disabled).
  ///
  /// In en, this message translates to:
  /// **'Other…'**
  String get otherApp;

  /// Creates a folder; also the name of the undoable operation.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolder;

  /// Pastes the copied items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Paste Item} =1{Paste Item} other{Paste {count} Items}}'**
  String pasteItems(int count);

  /// Submenu that chooses the view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Icon view.
  ///
  /// In en, this message translates to:
  /// **'Icons'**
  String get viewIcons;

  /// List view.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// Column view.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get viewColumns;

  /// Gallery view.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get viewGallery;

  /// Submenu that chooses the sort order.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// Sort by name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// Sort by type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sortKind;

  /// Sort by modification date.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get sortModified;

  /// Sort by size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortSize;

  /// Icon view sort order: no order, icons stay where the user puts them.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get sortNone;

  /// Icon view option: dropped icons land on the nearest free grid cell.
  ///
  /// In en, this message translates to:
  /// **'Snap to Grid'**
  String get snapToGrid;

  /// Icon view: moves icons that are off the grid to the nearest free cell.
  ///
  /// In en, this message translates to:
  /// **'Clean Up'**
  String get cleanUp;

  /// Icon view: like Clean Up, only for the selected icons.
  ///
  /// In en, this message translates to:
  /// **'Clean Up Selection'**
  String get cleanUpSelection;

  /// Icon view submenu: lays out all icons on the grid in an order, once.
  ///
  /// In en, this message translates to:
  /// **'Clean Up By'**
  String get cleanUpBy;

  /// List column header.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get columnName;

  /// List column header.
  ///
  /// In en, this message translates to:
  /// **'Date Modified'**
  String get columnModified;

  /// List column header.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get columnSize;

  /// List column header.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get columnKind;

  /// Sidebar section with the user folders.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get sidebarPinned;

  /// Sidebar section with home and Trash.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get sidebarPlaces;

  /// Sidebar section with the tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get sidebarTags;

  /// The Trash place.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// Name of the root disk in the path bar.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get disk;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get tagRed;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get tagOrange;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get tagYellow;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get tagGreen;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get tagBlue;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get tagPurple;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get tagGray;

  /// Error title when writing a tag fails.
  ///
  /// In en, this message translates to:
  /// **'Can\'t assign the tag.'**
  String get tagError;

  /// Error detail when writing a tag fails.
  ///
  /// In en, this message translates to:
  /// **'The disk does not support extended attributes.'**
  String get tagErrorDetail;

  /// Placeholder of the tag field in the preview pane.
  ///
  /// In en, this message translates to:
  /// **'Add a tag…'**
  String get addTag;

  /// Preview pane action that opens the file with its app.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get paneEdit;

  /// Tooltip and accessibility label of the Share button in the preview toolbar.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareLabel;

  /// Share menu item that copies the items to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get shareCopy;

  /// Preview pane action that opens the item menu.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get paneMore;

  /// Size of an empty file.
  ///
  /// In en, this message translates to:
  /// **'Zero bytes'**
  String get sizeZero;

  /// Size below 1000 bytes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 byte} other{{count} bytes}}'**
  String sizeBytes(int count);

  /// Decimal separator in sizes.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get decimalSeparator;

  /// Comma-separated short month names.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get monthsShort;

  /// Comma-separated month names.
  ///
  /// In en, this message translates to:
  /// **'January,February,March,April,May,June,July,August,September,October,November,December'**
  String get monthsLong;

  /// A date of today.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String dateToday(String time);

  /// A date of yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String dateYesterday(String time);

  /// A date with the short month name.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}, {time}'**
  String dateShort(String day, String month, String year, String time);

  /// A date with the full month name (Info window).
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}, {time}'**
  String dateLong(String day, String month, String year, String time);

  /// Type of a symbolic link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get kindLink;

  /// Type of a folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get kindFolder;

  /// Type of an image.
  ///
  /// In en, this message translates to:
  /// **'{format} image'**
  String kindImage(String format);

  /// Type of an audio file.
  ///
  /// In en, this message translates to:
  /// **'{format} audio'**
  String kindAudio(String format);

  /// Type of a video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get kindVideo;

  /// Type of an archive without extension.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get kindArchive;

  /// Type of an archive.
  ///
  /// In en, this message translates to:
  /// **'{ext} archive'**
  String kindArchiveExt(String ext);

  /// Type of a text file.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get kindText;

  /// Type of any other file.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get kindDocument;

  /// Name of a new folder on disk.
  ///
  /// In en, this message translates to:
  /// **'new folder'**
  String get newFolderName;

  /// Name of a duplicate.
  ///
  /// In en, this message translates to:
  /// **'{base} copy'**
  String copySuffix(String base);

  /// Name of a link made with Make Link.
  ///
  /// In en, this message translates to:
  /// **'{base} link'**
  String linkSuffix(String base);

  /// Name of the undoable Make Link.
  ///
  /// In en, this message translates to:
  /// **'Make Link'**
  String get opMakeLink;

  /// Name of the undoable Make Link of several items.
  ///
  /// In en, this message translates to:
  /// **'Make {count} links'**
  String opMakeLinkMany(int count);

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t make a link.'**
  String get cantMakeLink;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t show the original.'**
  String get cantShowOriginal;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The item no longer exists.'**
  String get errorGone;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The name “{name}” can\'t be used. Choose another name.'**
  String errorNameInvalid(String name);

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The name “{name}” can\'t be used. Try a name without the slash “/”.'**
  String errorNameSlash(String name);

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The name “{name}” is already taken. Choose another one.'**
  String errorNameTaken(String name);

  /// Error when restoring from the Trash.
  ///
  /// In en, this message translates to:
  /// **'It is not known where “{name}” came from.'**
  String errorUnknownOrigin(String name);

  /// Error when restoring from the Trash.
  ///
  /// In en, this message translates to:
  /// **'The original folder already has an item named “{name}”.'**
  String errorOriginTaken(String name);

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission for this operation.'**
  String get errorPermission;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The disk is full.'**
  String get errorDiskFull;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The disk is read-only.'**
  String get errorReadOnly;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'A folder can\'t be put inside itself.'**
  String get errorFolderIntoItself;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'There is already an item named “{name}”.'**
  String errorAlreadyExists(String name);

  /// Name of the undoable move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get opMove;

  /// Edit menu item.
  ///
  /// In en, this message translates to:
  /// **'Undo {action}'**
  String undoAction(String action);

  /// Edit menu item.
  ///
  /// In en, this message translates to:
  /// **'Redo {action}'**
  String redoAction(String action);

  /// Name of the undoable duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get opDuplicate;

  /// Name of the undoable duplicate of several items.
  ///
  /// In en, this message translates to:
  /// **'Duplicate {count} items'**
  String opDuplicateMany(int count);

  /// Error when redoing a duplicate whose source is gone.
  ///
  /// In en, this message translates to:
  /// **'Unknown copy'**
  String get unknownCopy;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The copy can\'t be redone.'**
  String get copyCantRedo;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t rename.'**
  String get cantRename;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t rename “{name}”.'**
  String cantRenameItem(String name);

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t create the folder.'**
  String get cantCreateFolder;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t duplicate.'**
  String get cantDuplicate;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t move to the Trash.'**
  String get cantTrash;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t restore.'**
  String get cantRestore;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t delete.'**
  String get cantDelete;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t undo.'**
  String get cantUndo;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t redo.'**
  String get cantRedo;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t complete the copy.'**
  String get cantCopy;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t complete the move.'**
  String get cantMove;

  /// Error shown in place of the list.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open: {error}'**
  String cantOpenFolder(String error);

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open a new window.'**
  String get cantOpenWindow;

  /// Error detail.
  ///
  /// In en, this message translates to:
  /// **'The Mustache desktop entry is not installed (cargo xtask install-app).'**
  String get entryNotInstalled;

  /// Title when a rename removes the extension.
  ///
  /// In en, this message translates to:
  /// **'Remove the extension “{old}”?'**
  String extensionRemove(String old);

  /// Title when a rename changes the extension.
  ///
  /// In en, this message translates to:
  /// **'Use the extension “{newExt}” instead of “{old}”?'**
  String extensionChange(String newExt, String old);

  /// Detail of the extension alert.
  ///
  /// In en, this message translates to:
  /// **'With another extension the file may open in a different app.'**
  String get extensionWarning;

  /// Keeps the old extension.
  ///
  /// In en, this message translates to:
  /// **'Keep {ext}'**
  String keepExtension(String ext);

  /// Removes the extension.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeExtension;

  /// Uses the new extension.
  ///
  /// In en, this message translates to:
  /// **'Use {ext}'**
  String useExtension(String ext);

  /// Title of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}” permanently?'**
  String confirmDeleteOne(String name);

  /// Title of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items permanently?'**
  String confirmDeleteMany(int count);

  /// Detail of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'This item will be deleted right away. This can\'t be undone.'**
  String get deleteWarningOne;

  /// Detail of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'These items will be deleted right away. This can\'t be undone.'**
  String get deleteWarningMany;

  /// Error when launching an app.
  ///
  /// In en, this message translates to:
  /// **'The entry of “{app}” has no command.'**
  String appHasNoCommand(String app);

  /// Error when launching an app.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open “{app}”: {error}'**
  String appCantOpen(String app, String error);

  /// Save dialog: an item with the name exists.
  ///
  /// In en, this message translates to:
  /// **'Replace “{name}”?'**
  String replaceQuestion(String name);

  /// Save dialog detail.
  ///
  /// In en, this message translates to:
  /// **'An item with this name already exists in this folder.'**
  String get replaceDetail;

  /// Label of the name field in the Save dialog.
  ///
  /// In en, this message translates to:
  /// **'Save as:'**
  String get saveAs;

  /// Search scope bar.
  ///
  /// In en, this message translates to:
  /// **'Search in:'**
  String get searchIn;

  /// Search scope: the whole computer.
  ///
  /// In en, this message translates to:
  /// **'This Computer'**
  String get thisComputer;

  /// Window title while searching.
  ///
  /// In en, this message translates to:
  /// **'Searching “{scope}”'**
  String searchTitle(String scope);

  /// A quoted name.
  ///
  /// In en, this message translates to:
  /// **'“{name}”'**
  String quoted(String name);

  /// Number of items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// Selected items in the status bar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{selected} of 1 selected} other{{selected} of {count} selected}}'**
  String selectedCount(int selected, int count);

  /// Status bar with the free space.
  ///
  /// In en, this message translates to:
  /// **'{head}, {free} available'**
  String available(String head, String free);

  /// Several items in the preview pane.
  ///
  /// In en, this message translates to:
  /// **'{count} documents - {size}'**
  String documentsSize(int count, String size);

  /// Preview pane section.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// Creation date label.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// Modification date label.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get modified;

  /// Size label.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// Tags label.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get infoGeneral;

  /// Info section with the metadata of the item.
  ///
  /// In en, this message translates to:
  /// **'More Info'**
  String get infoMoreInfo;

  /// More Info label: the MIME type.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get infoContentType;

  /// More Info label: the pixel size of an image.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get infoDimensions;

  /// Pixel size of an image.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height} pixels'**
  String infoPixels(int width, int height);

  /// More Info label: the last access date.
  ///
  /// In en, this message translates to:
  /// **'Last opened'**
  String get infoLastOpened;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'Name and Extension'**
  String get infoNameExtension;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get infoComments;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get infoPreview;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'Sharing and Permissions'**
  String get infoPermissions;

  /// Permission.
  ///
  /// In en, this message translates to:
  /// **'Read and write'**
  String get privilegeReadWrite;

  /// Permission.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get privilegeReadOnly;

  /// Permission.
  ///
  /// In en, this message translates to:
  /// **'Write only'**
  String get privilegeWriteOnly;

  /// Permission.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get privilegeNone;

  /// Title of the Info window.
  ///
  /// In en, this message translates to:
  /// **'{name} Info'**
  String infoTitle(String name);

  /// Info header.
  ///
  /// In en, this message translates to:
  /// **'Modified: {date}'**
  String modifiedOn(String date);

  /// Info row.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get kind;

  /// Info row.
  ///
  /// In en, this message translates to:
  /// **'{bytes} bytes ({disk} on disk)'**
  String sizeOnDisk(int bytes, String disk);

  /// Info row.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Info Open With row.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get app;

  /// No app.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// Info permissions row when the group is unknown.
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get groupFallback;

  /// Info permissions row for others.
  ///
  /// In en, this message translates to:
  /// **'everyone'**
  String get everyone;

  /// Owner row in Info.
  ///
  /// In en, this message translates to:
  /// **'{owner} (me)'**
  String ownerMe(String owner);

  /// Quick preview title with several items.
  ///
  /// In en, this message translates to:
  /// **'{name}  ({index} of {count})'**
  String positionOf(String name, int index, int count);

  /// Quick preview button.
  ///
  /// In en, this message translates to:
  /// **'Open with {app}'**
  String openWithApp(String app);

  /// Quick preview detail.
  ///
  /// In en, this message translates to:
  /// **'Last modified: {date}'**
  String lastModified(String date);

  /// Verb in the progress window.
  ///
  /// In en, this message translates to:
  /// **'Copying'**
  String get copying;

  /// Verb in the progress window.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get moving;

  /// Progress window line.
  ///
  /// In en, this message translates to:
  /// **'{verb} “{name}” to “{destination}”'**
  String transferLine(String verb, String name, String destination);

  /// Progress window bytes.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String progressOf(String done, String total);

  /// Conflict window.
  ///
  /// In en, this message translates to:
  /// **'An item named “{name}” already exists here. Replace it with the one you are copying?'**
  String conflictCopy(String name);

  /// Conflict window.
  ///
  /// In en, this message translates to:
  /// **'An item named “{name}” already exists here. Replace it with the one you are moving?'**
  String conflictMove(String name);

  /// Conflict choice.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get keepBoth;

  /// Conflict choice.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Folder context menu: opens the Customize Folder popover on the folder icon.
  ///
  /// In en, this message translates to:
  /// **'Customize Folder…'**
  String get customizeFolder;

  /// Customize Folder: the search found nothing, or the icons are not installed.
  ///
  /// In en, this message translates to:
  /// **'No symbols'**
  String get folderNoSymbols;

  /// Customize Folder: saving failed (no permission, read-only disk).
  ///
  /// In en, this message translates to:
  /// **'This folder can\'t be customized.'**
  String get folderStyleError;

  /// Customize Folder: removes every tag of the folder (it goes back to blue); also the hover caption.
  ///
  /// In en, this message translates to:
  /// **'Remove all tags'**
  String get folderRemoveAllTags;

  /// Customize Folder: the plus button after the colours (accessibility label).
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get folderAddTag;

  /// Customize Folder: the last item of the plus menu; shows the folder in the preview pane, where tags are typed.
  ///
  /// In en, this message translates to:
  /// **'Edit Tags…'**
  String get folderEditTags;

  /// Customize Folder: removes the symbol or emoji, keeps the tags.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get folderClear;

  /// Customize Folder: opens the emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get folderEmoji;

  /// Emoji picker: placeholder of the search field.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get emojiSearch;

  /// Emoji picker: the search found nothing.
  ///
  /// In en, this message translates to:
  /// **'No emoji found'**
  String get emojiNone;

  /// Customize Folder: symbol category.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get symbolPeople;

  /// Customize Folder: symbol category.
  ///
  /// In en, this message translates to:
  /// **'Animals & Nature'**
  String get symbolNature;

  /// Customize Folder: symbol category.
  ///
  /// In en, this message translates to:
  /// **'Food & Drink'**
  String get symbolFood;

  /// Customize Folder: symbol category.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get symbolActivities;

  /// Customize Folder: symbol category.
  ///
  /// In en, this message translates to:
  /// **'Travel & Places'**
  String get symbolTravel;

  /// Customize Folder: symbol category.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get symbolObjects;

  /// Customize Folder: symbol category.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get symbolSymbols;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Frequently Used'**
  String get emojiFrequent;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Smileys & People'**
  String get emojiSmileys;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Animals & Nature'**
  String get emojiAnimals;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Food & Drink'**
  String get emojiFood;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get emojiActivity;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Travel & Places'**
  String get emojiTravel;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get emojiObjects;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get emojiSymbols;

  /// Emoji picker: category heading and bar tooltip.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get emojiFlags;

  /// The File menu title.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// The Edit menu title.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// The Go menu title.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get menuGo;

  /// The Window menu title.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get menuWindow;

  /// The Help menu title.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// Button of the Empty Trash alert.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash'**
  String get menuEmptyTrashAction;

  /// Title of the Empty Trash alert.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently erase the items in the Trash?'**
  String get confirmEmptyTrash;

  /// Message of the Empty Trash alert.
  ///
  /// In en, this message translates to:
  /// **'You can’t undo this action.'**
  String get emptyTrashWarning;

  /// App menu (disabled until the Trash can be emptied).
  ///
  /// In en, this message translates to:
  /// **'Empty Trash…'**
  String get menuEmptyTrash;

  /// File menu: opens another window.
  ///
  /// In en, this message translates to:
  /// **'New Mustache Window'**
  String get menuNewWindow;

  /// File menu: new folder from the selected item; the name is quoted.
  ///
  /// In en, this message translates to:
  /// **'New Folder with {name}'**
  String menuNewFolderWith(String name);

  /// File menu: new folder from the selection (disabled).
  ///
  /// In en, this message translates to:
  /// **'New Folder with Selection'**
  String get menuNewFolderWithSelection;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'New Smart Folder'**
  String get menuNewSmartFolder;

  /// File menu: opens a tab.
  ///
  /// In en, this message translates to:
  /// **'New Tab'**
  String get menuNewTab;

  /// File menu: closes the tab or the window.
  ///
  /// In en, this message translates to:
  /// **'Close Window'**
  String get menuCloseWindow;

  /// File menu: opens the Info window of the selection.
  ///
  /// In en, this message translates to:
  /// **'Get Info'**
  String get menuGetInfo;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get menuCompress;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Make Link'**
  String get menuMakeLink;

  /// File menu: previews the selection.
  ///
  /// In en, this message translates to:
  /// **'Quick Look'**
  String get menuQuickLook;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get menuShare;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Manage Shared Folder…'**
  String get menuManageSharedFolder;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Manage Shared File…'**
  String get menuManageSharedFile;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Show Original'**
  String get menuShowOriginal;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Add to Sidebar'**
  String get menuAddToSidebar;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Eject'**
  String get menuEject;

  /// File menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get menuPrint;

  /// Edit menu, nothing to undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get menuUndo;

  /// Edit menu: redoes the undone operation.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get menuRedo;

  /// Edit menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get menuCut;

  /// Edit menu: copies the selected item; the name is quoted.
  ///
  /// In en, this message translates to:
  /// **'Copy {name}'**
  String menuCopyName(String name);

  /// Edit menu: copies several items.
  ///
  /// In en, this message translates to:
  /// **'Copy {count} Items'**
  String menuCopyItems(int count);

  /// Edit menu: selects every item.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get menuSelectAll;

  /// Edit menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Show Clipboard'**
  String get menuShowClipboard;

  /// Edit menu: starts a search.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get menuFind;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'as Icons'**
  String get menuAsIcons;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'as List'**
  String get menuAsList;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'as Columns'**
  String get menuAsColumns;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'as Gallery'**
  String get menuAsGallery;

  /// View menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Use Groups'**
  String get menuUseGroups;

  /// View menu on the desktop: groups the icons by type.
  ///
  /// In en, this message translates to:
  /// **'Use Stacks'**
  String get menuUseStacks;

  /// Sort By menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Last Opened'**
  String get menuSortLastOpened;

  /// Sort By menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get menuSortAdded;

  /// Sort By menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get menuSortCreated;

  /// Sort By menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get menuSortTags;

  /// View menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Show Tab Bar'**
  String get menuShowTabBar;

  /// View menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Show All Tabs'**
  String get menuShowAllTabs;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Hide Sidebar'**
  String get menuHideSidebar;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Show Sidebar'**
  String get menuShowSidebar;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Show Preview'**
  String get menuShowPreview;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Hide Preview'**
  String get menuHidePreview;

  /// View menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Hide Toolbar'**
  String get menuHideToolbar;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Show Path Bar'**
  String get menuShowPathBar;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Hide Path Bar'**
  String get menuHidePathBar;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Show Status Bar'**
  String get menuShowStatusBar;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Hide Status Bar'**
  String get menuHideStatusBar;

  /// View menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Customize Toolbar…'**
  String get menuCustomizeToolbar;

  /// View menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Show View Options'**
  String get menuShowViewOptions;

  /// View menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Show Preview Options'**
  String get menuShowPreviewOptions;

  /// Go menu.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get menuBack;

  /// Go menu.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get menuForward;

  /// Go menu: the parent folder.
  ///
  /// In en, this message translates to:
  /// **'Enclosing Folder'**
  String get menuEnclosingFolder;

  /// Go menu: the recently used files; also the title of that view.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get menuRecents;

  /// Go menu.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get menuDocuments;

  /// Go menu.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get menuDesktop;

  /// Go menu.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get menuDownloads;

  /// Go menu.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get menuHome;

  /// Go menu: the root of the file system.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get menuComputer;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Nearby Sharing'**
  String get menuNearbySharing;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get menuNetwork;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Cloud Drive'**
  String get menuCloudDrive;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get menuShared;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get menuApplications;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get menuUtilities;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Recent Folders'**
  String get menuRecentFolders;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Go to Folder…'**
  String get menuGoToFolder;

  /// Go menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Connect to Server…'**
  String get menuConnectToServer;

  /// Window menu.
  ///
  /// In en, this message translates to:
  /// **'Show Previous Tab'**
  String get menuPreviousTab;

  /// Window menu.
  ///
  /// In en, this message translates to:
  /// **'Show Next Tab'**
  String get menuNextTab;

  /// Window menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Move Tab to New Window'**
  String get menuMoveTabToWindow;

  /// Window menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Merge All Windows'**
  String get menuMergeWindows;

  /// Window menu (disabled).
  ///
  /// In en, this message translates to:
  /// **'Show Progress Window'**
  String get menuShowProgress;

  /// Placeholder of the search field in the toolbar.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchPlaceholder;

  /// Accessibility label of the toolbar button that shows or hides the sidebar.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get toggleSidebar;

  /// Accessibility label of the icon size slider in the status bar.
  ///
  /// In en, this message translates to:
  /// **'Icon size'**
  String get iconSize;

  /// Accessibility label of the close button of a tab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get menuCloseTab;

  /// Tooltip of a sheet's close button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeSheet;

  /// Header over the suggestions of the Go to Folder sheet.
  ///
  /// In en, this message translates to:
  /// **'Go to:'**
  String get goToFolderHeader;

  /// Header of the Go to Folder sheet when the typed path does not exist.
  ///
  /// In en, this message translates to:
  /// **'Folder not found'**
  String get goToFolderNotFound;

  /// Title of the Save Search sheet.
  ///
  /// In en, this message translates to:
  /// **'Save this search'**
  String get saveSearchTitle;

  /// Message of the Save Search sheet.
  ///
  /// In en, this message translates to:
  /// **'Name it and choose where to keep it.'**
  String get saveSearchMessage;

  /// Label of the name field of the Save Search sheet.
  ///
  /// In en, this message translates to:
  /// **'Save As:'**
  String get saveSearchName;

  /// Label of the tags field of the Save Search sheet.
  ///
  /// In en, this message translates to:
  /// **'Tags:'**
  String get saveSearchTags;

  /// Label of the folder pop-up of the Save Search sheet.
  ///
  /// In en, this message translates to:
  /// **'Where:'**
  String get saveSearchWhere;

  /// Placeholder of the tags field of the Save Search sheet.
  ///
  /// In en, this message translates to:
  /// **'Add tags'**
  String get saveSearchAddTags;

  /// Checkbox of the Save Search sheet.
  ///
  /// In en, this message translates to:
  /// **'Add to Sidebar'**
  String get saveSearchAddToSidebar;

  /// The folder saved searches are kept in, and the sidebar section.
  ///
  /// In en, this message translates to:
  /// **'Saved Searches'**
  String get savedSearchesFolder;

  /// Default name of a saved search in a folder, for example Documents named Lemon.
  ///
  /// In en, this message translates to:
  /// **'{folder} named {query}'**
  String savedSearchNameInFolder(String folder, String query);

  /// Default name of a saved search of this computer.
  ///
  /// In en, this message translates to:
  /// **'Search for {query}'**
  String savedSearchNameEverywhere(String query);

  /// Alert title when the saved search file cannot be written.
  ///
  /// In en, this message translates to:
  /// **'The search could not be saved'**
  String get saveSearchError;

  /// The Save button of the scope bar.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveSearchButton;

  /// Alert when a .search file is damaged.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is not a saved search.'**
  String savedSearchDamaged(String name);

  /// Title of the Settings window.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings pane.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// Settings pane.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get settingsTags;

  /// Settings pane.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get settingsSidebar;

  /// Settings pane.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// Settings › General heading.
  ///
  /// In en, this message translates to:
  /// **'Windows and names'**
  String get settingsWindowsAndNames;

  /// Settings › General: the folder a new window opens at.
  ///
  /// In en, this message translates to:
  /// **'New windows show'**
  String get settingsNewWindowsShow;

  /// Settings › General: New Window opens a tab.
  ///
  /// In en, this message translates to:
  /// **'Open folders in tabs instead of new windows'**
  String get settingsOpenInTabs;

  /// The user's home folder, in Settings.
  ///
  /// In en, this message translates to:
  /// **'Home folder'**
  String get settingsHomeFolder;

  /// Settings › Tags heading.
  ///
  /// In en, this message translates to:
  /// **'Show these tags in the sidebar'**
  String get settingsShowTags;

  /// Settings › Tags heading.
  ///
  /// In en, this message translates to:
  /// **'Favourite tags'**
  String get settingsFavouriteTags;

  /// Settings › Tags caption.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder: the first seven appear in the context menu.'**
  String get settingsFavouritesCaption;

  /// Settings › Tags switch.
  ///
  /// In en, this message translates to:
  /// **'Colour folders by tag'**
  String get settingsColourFolders;

  /// Settings › Advanced heading.
  ///
  /// In en, this message translates to:
  /// **'Ask for confirmation before'**
  String get settingsConfirmBefore;

  /// Settings › Advanced.
  ///
  /// In en, this message translates to:
  /// **'Changing a file extension'**
  String get settingsConfirmExtension;

  /// Settings › Advanced.
  ///
  /// In en, this message translates to:
  /// **'Emptying the Trash'**
  String get settingsConfirmTrash;

  /// Settings › Advanced switch.
  ///
  /// In en, this message translates to:
  /// **'Remove items from the Trash after 30 days'**
  String get settingsTrashCleanup;

  /// Settings › Advanced heading.
  ///
  /// In en, this message translates to:
  /// **'Keep folders on top'**
  String get settingsFoldersOnTop;

  /// Settings › Advanced.
  ///
  /// In en, this message translates to:
  /// **'In windows when sorting by name'**
  String get settingsFoldersOnTopWindows;

  /// Settings › Advanced.
  ///
  /// In en, this message translates to:
  /// **'On the desktop'**
  String get settingsFoldersOnTopDesktop;

  /// Settings › Advanced heading.
  ///
  /// In en, this message translates to:
  /// **'When searching'**
  String get settingsWhenSearching;

  /// Settings › Advanced: default search scope.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get settingsSearchIn;

  /// Settings › Advanced: search scope.
  ///
  /// In en, this message translates to:
  /// **'Current folder'**
  String get settingsCurrentFolder;

  /// Accessibility label of the Actions button of the toolbar and its item in the overflow menu.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get toolbarActions;

  /// Accessibility label of the Tags button of the toolbar and header of its popover.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get toolbarTags;

  /// Accessibility label of the overflow button of the toolbar.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get toolbarMore;

  /// Item of the Tags popover that lists every tag colour, not only the favourites.
  ///
  /// In en, this message translates to:
  /// **'Show All…'**
  String get tagsShowAll;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
