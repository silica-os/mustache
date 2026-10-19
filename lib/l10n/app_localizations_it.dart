// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get open => 'Apri';

  @override
  String get save => 'Salva';

  @override
  String get cancel => 'Annulla';

  @override
  String get replace => 'Sostituisci';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Elimina';

  @override
  String get openWith => 'Apri con';

  @override
  String get showInfo => 'Ottieni informazioni';

  @override
  String get rename => 'Rinomina';

  @override
  String get renameMany => 'Rinomina…';

  @override
  String get duplicate => 'Duplica';

  @override
  String get copy => 'Copia';

  @override
  String get tagsMenu => 'Tag…';

  @override
  String get moveToTrash => 'Sposta nel Cestino';

  @override
  String get restore => 'Ripristina';

  @override
  String newFolderWithSelection(int count) {
    return 'Nuova cartella con selezione ($count elementi)';
  }

  @override
  String defaultApp(String app) {
    return '$app (predefinita)';
  }

  @override
  String get otherApp => 'Altro…';

  @override
  String get newFolder => 'Nuova cartella';

  @override
  String pasteItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Incolla $count elementi',
      one: 'Incolla elemento',
      zero: 'Incolla elemento',
    );
    return '$_temp0';
  }

  @override
  String get view => 'Vista';

  @override
  String get viewIcons => 'Come icone';

  @override
  String get viewList => 'Come elenco';

  @override
  String get viewColumns => 'Come colonne';

  @override
  String get viewGallery => 'Come galleria';

  @override
  String get sortBy => 'Ordina per';

  @override
  String get sortName => 'Nome';

  @override
  String get sortKind => 'Tipo';

  @override
  String get sortModified => 'Data di modifica';

  @override
  String get sortSize => 'Dimensione';

  @override
  String get sortNone => 'Nessuno';

  @override
  String get snapToGrid => 'Allinea alla griglia';

  @override
  String get cleanUp => 'Allinea';

  @override
  String get cleanUpSelection => 'Allinea selezione';

  @override
  String get cleanUpBy => 'Disponi per';

  @override
  String get columnName => 'Nome';

  @override
  String get columnModified => 'Data di modifica';

  @override
  String get columnSize => 'Dimensioni';

  @override
  String get columnKind => 'Tipo';

  @override
  String get sidebarPinned => 'Preferiti';

  @override
  String get sidebarPlaces => 'Posizioni';

  @override
  String get sidebarTags => 'Tag';

  @override
  String get trash => 'Cestino';

  @override
  String get disk => 'Disco';

  @override
  String get tagRed => 'Rosso';

  @override
  String get tagOrange => 'Arancio';

  @override
  String get tagYellow => 'Giallo';

  @override
  String get tagGreen => 'Verde';

  @override
  String get tagBlue => 'Blu';

  @override
  String get tagPurple => 'Viola';

  @override
  String get tagGray => 'Grigio';

  @override
  String get tagError => 'Non si può assegnare l\'etichetta.';

  @override
  String get tagErrorDetail => 'Il disco non permette gli attributi estesi.';

  @override
  String get addTag => 'Aggiungi un tag…';

  @override
  String get paneEdit => 'Modifica';

  @override
  String get shareLabel => 'Condividi';

  @override
  String get shareCopy => 'Copia';

  @override
  String get paneMore => 'Altro';

  @override
  String get sizeZero => 'Zero byte';

  @override
  String sizeBytes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count byte',
    );
    return '$_temp0';
  }

  @override
  String get decimalSeparator => ',';

  @override
  String get monthsShort => 'gen,feb,mar,apr,mag,giu,lug,ago,set,ott,nov,dic';

  @override
  String get monthsLong =>
      'gennaio,febbraio,marzo,aprile,maggio,giugno,luglio,agosto,settembre,ottobre,novembre,dicembre';

  @override
  String dateToday(String time) {
    return 'oggi, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'ieri, $time';
  }

  @override
  String dateShort(String day, String month, String year, String time) {
    return '$day $month $year, $time';
  }

  @override
  String dateLong(String day, String month, String year, String time) {
    return '$day $month $year, $time';
  }

  @override
  String get kindLink => 'Collegamento';

  @override
  String get kindFolder => 'Cartella';

  @override
  String kindImage(String format) {
    return 'Immagine $format';
  }

  @override
  String kindAudio(String format) {
    return 'Audio $format';
  }

  @override
  String get kindVideo => 'Video';

  @override
  String get kindArchive => 'Archivio';

  @override
  String kindArchiveExt(String ext) {
    return 'Archivio $ext';
  }

  @override
  String get kindText => 'Testo';

  @override
  String get kindDocument => 'Documento';

  @override
  String get newFolderName => 'cartella senza nome';

  @override
  String copySuffix(String base) {
    return '$base copia';
  }

  @override
  String linkSuffix(String base) {
    return '$base collegamento';
  }

  @override
  String get opMakeLink => 'Creazione collegamento';

  @override
  String opMakeLinkMany(int count) {
    return 'Creazione di $count collegamenti';
  }

  @override
  String get cantMakeLink => 'Non si può creare il collegamento.';

  @override
  String get cantShowOriginal => 'Non si può mostrare l\'originale.';

  @override
  String get errorGone => 'L\'elemento non esiste più.';

  @override
  String errorNameInvalid(String name) {
    return 'Il nome «$name» non può essere utilizzato. Scegli un altro nome.';
  }

  @override
  String errorNameSlash(String name) {
    return 'Il nome «$name» non può essere utilizzato. Prova a usare un nome senza la barra «/».';
  }

  @override
  String errorNameTaken(String name) {
    return 'Il nome «$name» è già stato assegnato. Scegline un altro.';
  }

  @override
  String errorUnknownOrigin(String name) {
    return 'Non si sa da dove viene «$name».';
  }

  @override
  String errorOriginTaken(String name) {
    return 'Nella cartella d\'origine c\'è già un elemento chiamato «$name».';
  }

  @override
  String get errorPermission => 'Non hai i permessi per questa operazione.';

  @override
  String get errorDiskFull => 'Il disco è pieno.';

  @override
  String get errorReadOnly => 'Il disco è di sola lettura.';

  @override
  String get errorFolderIntoItself =>
      'Non si può mettere una cartella dentro se stessa.';

  @override
  String errorAlreadyExists(String name) {
    return 'C\'è già un elemento chiamato «$name».';
  }

  @override
  String get opMove => 'Sposta';

  @override
  String undoAction(String action) {
    return 'Annulla $action';
  }

  @override
  String redoAction(String action) {
    return 'Ripeti $action';
  }

  @override
  String get opDuplicate => 'Duplicazione';

  @override
  String opDuplicateMany(int count) {
    return 'Duplicazione di $count elementi';
  }

  @override
  String get unknownCopy => 'Copia sconosciuta';

  @override
  String get copyCantRedo => 'La copia non si può ripetere.';

  @override
  String get cantRename => 'Non si può rinominare.';

  @override
  String cantRenameItem(String name) {
    return 'Non si può rinominare «$name».';
  }

  @override
  String get cantCreateFolder => 'Non si può creare la cartella.';

  @override
  String get cantDuplicate => 'Non si può duplicare.';

  @override
  String get cantTrash => 'Non si può spostare nel Cestino.';

  @override
  String get cantRestore => 'Non si può ripristinare.';

  @override
  String get cantDelete => 'Non si può eliminare.';

  @override
  String get cantUndo => 'Non si può annullare.';

  @override
  String get cantRedo => 'Non si può ripetere.';

  @override
  String get cantCopy => 'Non si può completare la copia.';

  @override
  String get cantMove => 'Non si può completare lo spostamento.';

  @override
  String cantOpenFolder(String error) {
    return 'Non si può aprire: $error';
  }

  @override
  String get cantOpenWindow => 'Non si può aprire una finestra nuova.';

  @override
  String get entryNotInstalled =>
      'La voce di Mustache non è installata (cargo xtask install-app).';

  @override
  String extensionRemove(String old) {
    return 'Vuoi togliere l\'estensione «$old»?';
  }

  @override
  String extensionChange(String newExt, String old) {
    return 'Vuoi usare l\'estensione «$newExt» invece di «$old»?';
  }

  @override
  String get extensionWarning =>
      'Cambiando l\'estensione il file potrebbe aprirsi con un\'altra app.';

  @override
  String keepExtension(String ext) {
    return 'Mantieni $ext';
  }

  @override
  String get removeExtension => 'Togli';

  @override
  String useExtension(String ext) {
    return 'Usa $ext';
  }

  @override
  String confirmDeleteOne(String name) {
    return 'Confermi di voler eliminare «$name»?';
  }

  @override
  String confirmDeleteMany(int count) {
    return 'Confermi di voler eliminare $count elementi?';
  }

  @override
  String get deleteWarningOne =>
      'Questo elemento verrà eliminato immediatamente. L\'operazione è irreversibile.';

  @override
  String get deleteWarningMany =>
      'Questi elementi verranno eliminati immediatamente. L\'operazione è irreversibile.';

  @override
  String appHasNoCommand(String app) {
    return 'La voce di «$app» non ha un comando.';
  }

  @override
  String appCantOpen(String app, String error) {
    return 'Non si può aprire «$app»: $error';
  }

  @override
  String replaceQuestion(String name) {
    return 'Vuoi sostituire «$name»?';
  }

  @override
  String get replaceDetail =>
      'Esiste già un elemento con questo nome in questa cartella.';

  @override
  String get saveAs => 'Salva con nome:';

  @override
  String get searchIn => 'Cerca in:';

  @override
  String get thisComputer => 'Questo computer';

  @override
  String searchTitle(String scope) {
    return 'Ricerca in «$scope»';
  }

  @override
  String quoted(String name) {
    return '«$name»';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String selectedCount(int selected, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$selected di $count selezionati',
      one: '$selected di 1 selezionato',
    );
    return '$_temp0';
  }

  @override
  String available(String head, String free) {
    return '$head, $free disponibili';
  }

  @override
  String documentsSize(int count, String size) {
    return '$count documenti - $size';
  }

  @override
  String get information => 'Informazioni';

  @override
  String get created => 'Creato';

  @override
  String get modified => 'Modificato';

  @override
  String get size => 'Dimensioni';

  @override
  String get tags => 'Tag';

  @override
  String get infoGeneral => 'Generali';

  @override
  String get infoMoreInfo => 'Altre informazioni';

  @override
  String get infoContentType => 'Tipo di contenuto';

  @override
  String get infoDimensions => 'Dimensioni';

  @override
  String infoPixels(int width, int height) {
    return '$width × $height pixel';
  }

  @override
  String get infoLastOpened => 'Ultima apertura';

  @override
  String get infoNameExtension => 'Nome ed estensione';

  @override
  String get infoComments => 'Commenti';

  @override
  String get infoPreview => 'Anteprima';

  @override
  String get infoPermissions => 'Condivisione e permessi';

  @override
  String get privilegeReadWrite => 'Lettura e scrittura';

  @override
  String get privilegeReadOnly => 'Sola lettura';

  @override
  String get privilegeWriteOnly => 'Sola scrittura';

  @override
  String get privilegeNone => 'Nessun accesso';

  @override
  String infoTitle(String name) {
    return 'Info su $name';
  }

  @override
  String modifiedOn(String date) {
    return 'Modificato: $date';
  }

  @override
  String get kind => 'Tipo';

  @override
  String sizeOnDisk(int bytes, String disk) {
    return '$bytes byte ($disk su disco)';
  }

  @override
  String get location => 'Situato in';

  @override
  String get app => 'App';

  @override
  String get none => 'Nessuna';

  @override
  String get groupFallback => 'gruppo';

  @override
  String get everyone => 'tutti';

  @override
  String ownerMe(String owner) {
    return '$owner (io)';
  }

  @override
  String positionOf(String name, int index, int count) {
    return '$name  ($index di $count)';
  }

  @override
  String openWithApp(String app) {
    return 'Apri con $app';
  }

  @override
  String lastModified(String date) {
    return 'Ultima modifica: $date';
  }

  @override
  String get copying => 'Copio';

  @override
  String get moving => 'Sposto';

  @override
  String transferLine(String verb, String name, String destination) {
    return '$verb «$name» in «$destination»';
  }

  @override
  String progressOf(String done, String total) {
    return '$done di $total';
  }

  @override
  String conflictCopy(String name) {
    return 'In questa posizione c\'è già un elemento chiamato «$name». Vuoi sostituirlo con quello che stai copiando?';
  }

  @override
  String conflictMove(String name) {
    return 'In questa posizione c\'è già un elemento chiamato «$name». Vuoi sostituirlo con quello che stai spostando?';
  }

  @override
  String get keepBoth => 'Mantieni entrambi';

  @override
  String get stop => 'Interrompi';

  @override
  String get customizeFolder => 'Personalizza cartella…';

  @override
  String get folderNoSymbols => 'Nessun simbolo';

  @override
  String get folderStyleError =>
      'Non è possibile personalizzare questa cartella.';

  @override
  String get folderRemoveAllTags => 'Rimuovi tutti i tag';

  @override
  String get folderAddTag => 'Aggiungi tag';

  @override
  String get folderEditTags => 'Modifica tag…';

  @override
  String get folderClear => 'Cancella';

  @override
  String get folderEmoji => 'Emoji';

  @override
  String get emojiSearch => 'Cerca';

  @override
  String get emojiNone => 'Nessuna emoji trovata';

  @override
  String get symbolPeople => 'Persone';

  @override
  String get symbolNature => 'Animali e natura';

  @override
  String get symbolFood => 'Cibo e bevande';

  @override
  String get symbolActivities => 'Attività';

  @override
  String get symbolTravel => 'Viaggi e luoghi';

  @override
  String get symbolObjects => 'Oggetti';

  @override
  String get symbolSymbols => 'Simboli';

  @override
  String get emojiFrequent => 'Usate di frequente';

  @override
  String get emojiSmileys => 'Faccine e persone';

  @override
  String get emojiAnimals => 'Animali e natura';

  @override
  String get emojiFood => 'Cibo e bevande';

  @override
  String get emojiActivity => 'Attività';

  @override
  String get emojiTravel => 'Viaggi e luoghi';

  @override
  String get emojiObjects => 'Oggetti';

  @override
  String get emojiSymbols => 'Simboli';

  @override
  String get emojiFlags => 'Bandiere';

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Modifica';

  @override
  String get menuGo => 'Vai';

  @override
  String get menuWindow => 'Finestra';

  @override
  String get menuHelp => 'Aiuto';

  @override
  String get menuEmptyTrashAction => 'Svuota il Cestino';

  @override
  String get confirmEmptyTrash =>
      'Vuoi davvero eliminare definitivamente gli elementi nel Cestino?';

  @override
  String get emptyTrashWarning => 'Questa azione non può essere annullata.';

  @override
  String get menuEmptyTrash => 'Svuota il Cestino…';

  @override
  String get menuNewWindow => 'Nuova finestra di Mustache';

  @override
  String menuNewFolderWith(String name) {
    return 'Nuova cartella con $name';
  }

  @override
  String get menuNewFolderWithSelection => 'Nuova cartella con selezione';

  @override
  String get menuNewSmartFolder => 'Nuova cartella smart';

  @override
  String get menuNewTab => 'Nuovo pannello';

  @override
  String get menuCloseWindow => 'Chiudi finestra';

  @override
  String get menuGetInfo => 'Ottieni informazioni';

  @override
  String get menuCompress => 'Comprimi';

  @override
  String get menuMakeLink => 'Crea alias';

  @override
  String get menuQuickLook => 'Visualizzazione rapida';

  @override
  String get menuShare => 'Condividi…';

  @override
  String get menuManageSharedFolder => 'Gestisci cartella condivisa…';

  @override
  String get menuManageSharedFile => 'Gestisci file condiviso…';

  @override
  String get menuShowOriginal => 'Mostra originale';

  @override
  String get menuAddToSidebar => 'Aggiungi alla barra laterale';

  @override
  String get menuEject => 'Espelli';

  @override
  String get menuPrint => 'Stampa';

  @override
  String get menuUndo => 'Annulla';

  @override
  String get menuRedo => 'Ripristina';

  @override
  String get menuCut => 'Taglia';

  @override
  String menuCopyName(String name) {
    return 'Copia $name';
  }

  @override
  String menuCopyItems(int count) {
    return 'Copia $count elementi';
  }

  @override
  String get menuSelectAll => 'Seleziona tutto';

  @override
  String get menuShowClipboard => 'Mostra gli appunti';

  @override
  String get menuFind => 'Cerca';

  @override
  String get menuAsIcons => 'Come icone';

  @override
  String get menuAsList => 'Come elenco';

  @override
  String get menuAsColumns => 'Come colonne';

  @override
  String get menuAsGallery => 'Come galleria';

  @override
  String get menuUseGroups => 'Utilizza gruppi';

  @override
  String get menuUseStacks => 'Utilizza pile';

  @override
  String get menuSortLastOpened => 'Data ultima apertura';

  @override
  String get menuSortAdded => 'Data di aggiunta';

  @override
  String get menuSortCreated => 'Data di creazione';

  @override
  String get menuSortTags => 'Tag';

  @override
  String get menuShowTabBar => 'Mostra la barra dei pannelli';

  @override
  String get menuShowAllTabs => 'Mostra tutti i pannelli';

  @override
  String get menuHideSidebar => 'Nascondi la barra laterale';

  @override
  String get menuShowSidebar => 'Mostra la barra laterale';

  @override
  String get menuShowPreview => 'Mostra anteprima';

  @override
  String get menuHidePreview => 'Nascondi anteprima';

  @override
  String get menuHideToolbar => 'Nascondi la barra strumenti';

  @override
  String get menuShowPathBar => 'Mostra la barra del percorso';

  @override
  String get menuHidePathBar => 'Nascondi la barra del percorso';

  @override
  String get menuShowStatusBar => 'Mostra la barra di stato';

  @override
  String get menuHideStatusBar => 'Nascondi la barra di stato';

  @override
  String get menuCustomizeToolbar => 'Personalizza la barra strumenti…';

  @override
  String get menuShowViewOptions => 'Mostra opzioni Vista';

  @override
  String get menuShowPreviewOptions => 'Mostra opzioni anteprima';

  @override
  String get menuBack => 'Indietro';

  @override
  String get menuForward => 'Avanti';

  @override
  String get menuEnclosingFolder => 'Cartella dell’elemento';

  @override
  String get menuRecents => 'Recenti';

  @override
  String get menuDocuments => 'Documenti';

  @override
  String get menuDesktop => 'Scrivania';

  @override
  String get menuDownloads => 'Download';

  @override
  String get menuHome => 'Inizio';

  @override
  String get menuComputer => 'Computer';

  @override
  String get menuNearbySharing => 'Condivisione nelle vicinanze';

  @override
  String get menuNetwork => 'Rete';

  @override
  String get menuCloudDrive => 'Drive cloud';

  @override
  String get menuShared => 'Condivisi';

  @override
  String get menuApplications => 'Applicazioni';

  @override
  String get menuUtilities => 'Utility';

  @override
  String get menuRecentFolders => 'Cartelle recenti';

  @override
  String get menuGoToFolder => 'Vai alla cartella…';

  @override
  String get menuConnectToServer => 'Connessione al server…';

  @override
  String get menuPreviousTab => 'Mostra pannello precedente';

  @override
  String get menuNextTab => 'Mostra pannello successivo';

  @override
  String get menuMoveTabToWindow => 'Sposta pannello in una nuova finestra';

  @override
  String get menuMergeWindows => 'Unisci tutte le finestre';

  @override
  String get menuShowProgress => 'Mostra finestra avanzamento';

  @override
  String get searchPlaceholder => 'Cerca';

  @override
  String get toggleSidebar => 'Barra laterale';

  @override
  String get iconSize => 'Dimensione icone';

  @override
  String get menuCloseTab => 'Chiudi tab';

  @override
  String get closeSheet => 'Chiudi';

  @override
  String get goToFolderHeader => 'Vai a:';

  @override
  String get goToFolderNotFound => 'Cartella non trovata';

  @override
  String get saveSearchTitle => 'Salva questa ricerca';

  @override
  String get saveSearchMessage => 'Dai un nome e scegli dove tenerla.';

  @override
  String get saveSearchName => 'Salva come:';

  @override
  String get saveSearchTags => 'Tag:';

  @override
  String get saveSearchWhere => 'Dove:';

  @override
  String get saveSearchAddTags => 'Aggiungi tag';

  @override
  String get saveSearchAddToSidebar => 'Aggiungi alla barra laterale';

  @override
  String get savedSearchesFolder => 'Ricerche salvate';

  @override
  String savedSearchNameInFolder(String folder, String query) {
    return '$folder con nome $query';
  }

  @override
  String savedSearchNameEverywhere(String query) {
    return 'Ricerca di $query';
  }

  @override
  String get saveSearchError => 'Impossibile salvare la ricerca';

  @override
  String get saveSearchButton => 'Salva';

  @override
  String savedSearchDamaged(String name) {
    return '“$name” non è una ricerca salvata.';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsGeneral => 'Generali';

  @override
  String get settingsTags => 'Tag';

  @override
  String get settingsSidebar => 'Barra laterale';

  @override
  String get settingsAdvanced => 'Avanzate';

  @override
  String get settingsWindowsAndNames => 'Finestre e nomi';

  @override
  String get settingsNewWindowsShow => 'Le nuove finestre mostrano';

  @override
  String get settingsOpenInTabs =>
      'Apri le cartelle in tab invece che in nuove finestre';

  @override
  String get settingsHomeFolder => 'Cartella Home';

  @override
  String get settingsShowTags => 'Mostra questi tag nella barra laterale';

  @override
  String get settingsFavouriteTags => 'Tag preferiti';

  @override
  String get settingsFavouritesCaption =>
      'Trascina per riordinare: i primi sette compaiono nel menu contestuale.';

  @override
  String get settingsColourFolders => 'Colora le cartelle in base al tag';

  @override
  String get settingsConfirmBefore => 'Chiedi conferma prima di';

  @override
  String get settingsConfirmExtension => 'Cambiare l’estensione di un file';

  @override
  String get settingsConfirmTrash => 'Svuotare il Cestino';

  @override
  String get settingsTrashCleanup =>
      'Rimuovi gli elementi dal Cestino dopo 30 giorni';

  @override
  String get settingsFoldersOnTop => 'Tieni le cartelle in cima';

  @override
  String get settingsFoldersOnTopWindows =>
      'Nelle finestre se ordinate per nome';

  @override
  String get settingsFoldersOnTopDesktop => 'Sulla scrivania';

  @override
  String get settingsWhenSearching => 'Durante la ricerca';

  @override
  String get settingsSearchIn => 'Cerca in';

  @override
  String get settingsCurrentFolder => 'Cartella corrente';

  @override
  String get toolbarActions => 'Azioni';

  @override
  String get toolbarTags => 'Tag';

  @override
  String get toolbarMore => 'Altro';

  @override
  String get tagsShowAll => 'Mostra tutti…';

  @override
  String get sidebarApplications => 'Applicazioni';

  @override
  String get ejectButton => 'Espelli';

  @override
  String volumeBusy(String name) {
    return 'Impossibile espellere “$name” perché è in uso.';
  }

  @override
  String volumeBadSignature(String name) {
    return 'Impossibile aprire “$name”: l’immagine disco è danneggiata o è stata modificata.';
  }

  @override
  String volumeUnsigned(String name) {
    return 'Impossibile aprire “$name” perché non è firmata dal suo sviluppatore.';
  }

  @override
  String volumeRevoked(String name) {
    return '“$name” proviene da uno sviluppatore la cui chiave è stata revocata.';
  }

  @override
  String volumeFailed(String name) {
    return 'Impossibile aprire “$name”.';
  }

  @override
  String licenseTitle(String name) {
    return 'Per usare “$name” devi accettarne la licenza.';
  }

  @override
  String get licenseAgree => 'Accetta';

  @override
  String get licenseDisagree => 'Rifiuta';

  @override
  String installExists(String name) {
    return 'In Applicazioni esiste già un’app chiamata “$name”. Vuoi sostituirla?';
  }

  @override
  String get installReplace => 'Sostituisci';

  @override
  String get installStop => 'Interrompi';

  @override
  String installFailed(String name) {
    return 'Impossibile copiare “$name” in Applicazioni.';
  }

  @override
  String installEject(String name) {
    return 'Espellere “$name” e spostare l’immagine disco nel Cestino?';
  }

  @override
  String get installKeep => 'Mantieni';

  @override
  String appIsSystem(String name) {
    return '“$name” fa parte di Silica e non può essere spostata nel Cestino.';
  }

  @override
  String appIsRunning(String name) {
    return '“$name” è aperta. Chiudila prima di spostarla nel Cestino.';
  }

  @override
  String get showPackageContents => 'Mostra contenuto pacchetto';

  @override
  String get installKeepBoth => 'Mantieni entrambe';

  @override
  String get kindApplication => 'Applicazione';

  @override
  String get kindFlatpakApp => 'Applicazione (Flatpak)';

  @override
  String get infoVersion => 'Versione';

  @override
  String get infoDeveloper => 'Sviluppatore';

  @override
  String get infoSignature => 'Firma';

  @override
  String get infoAccess => 'Accesso';

  @override
  String get signatureVerified => 'Sviluppatore identificato';

  @override
  String get signatureSelfSigned => 'Autofirmata';

  @override
  String get signatureUnsigned => 'Non firmata';

  @override
  String get signatureRevoked => 'Sviluppatore revocato';

  @override
  String get signatureTampered => 'Danneggiata o modificata';

  @override
  String get signatureSystem => 'Parte di Silica';

  @override
  String get signatureFlatpak => 'Installata con Flatpak';

  @override
  String get accessSystem => 'Tutto il computer (app di sistema)';

  @override
  String get accessNetwork => 'Rete';

  @override
  String get accessHome => 'Cartella Inizio';

  @override
  String get accessFolders => 'Alcune cartelle';

  @override
  String get accessDevices => 'Tutti i dispositivi';

  @override
  String get accessBackground => 'In background';

  @override
  String get accessNone => 'Solo i suoi file';

  @override
  String installedInApplications(String name) {
    return '“$name” ora è in Applicazioni.';
  }

  @override
  String quitAndMoveTitle(String name) {
    return '“$name” è aperta. Vuoi chiuderla e spostarla nel Cestino?';
  }

  @override
  String get quitAndMove => 'Chiudi e sposta';

  @override
  String get sidebarLocations => 'Posizioni';

  @override
  String ejectVolume(String name) {
    return 'Espelli $name';
  }

  @override
  String get infoRunInSandbox => 'Esegui in sandbox';

  @override
  String get infoSandboxFailed =>
      'Non è stato possibile cambiare l’impostazione della sandbox.';
}
