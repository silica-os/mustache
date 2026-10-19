// The apps that open a file (MU-50, docs/spec R10.1): the session's app registry (Launch
// Services, silica-daemon's Apps1 through `SilicaApps`: desktop entries, app bundles, AppImages,
// Flatpak apps) when it runs, else the .desktop entries with `MimeType` (freedesktop Desktop
// Entry specification); the choices of `mimeapps.list` (the "Association between MIME types and
// applications" specification: defaults, added, removed); launching through the registry, or
// with the field codes of `Exec`.

import 'external.dart';

import 'dart:io';

import 'package:silica_ui/silica_ui.dart'
    show
        MimeDatabase,
        SilicaApps,
        SilicaInstalledApp,
        SilicaInstalledAppKind,
        xdgDataDirs;

import 'l10n.dart';

/// An installed app that declares the types it opens.
class DesktopApp {
  const DesktopApp({
    required this.id,
    required this.name,
    required this.exec,
    this.mimeTypes = const [],
    this.icon,
    this.silicaIcon,
    this.terminal = false,
    this.appId,
  });

  /// The id of the entry (`org.gnome.TextEditor.desktop`).
  final String id;
  final String name;
  final String exec;
  final List<String> mimeTypes;
  final String? icon;

  /// `X-Silica-Icon`: the silica-icons name or the `icon/` folder of one of Silica's own apps;
  /// null for every other app.
  final String? silicaIcon;
  final bool terminal;

  /// The id of the app in the session's registry (Launch Services): launched through it.
  final String? appId;
}

/// The registry's apps as Mustache's, keyed by the desktop file id that `mimeapps.list` uses for
/// them (`<id>.desktop`; `silica-bundles-<id>.desktop` for bundles and AppImages, whose entries
/// the registry writes in `applications/silica-bundles/`). Apps that ask not to be shown are
/// left out.
Map<String, DesktopApp> appsFromInstalled(
  Iterable<SilicaInstalledApp> apps, {
  String? locale,
}) {
  locale ??= l10n.localeName;
  return {
    for (final app in apps)
      if (!app.noDisplay && app.exec.isNotEmpty)
        desktopIdOf(app): DesktopApp(
          id: desktopIdOf(app),
          name: app.nameIn(locale),
          exec: app.exec,
          mimeTypes: app.mimeTypes,
          icon: app.icon.isEmpty ? null : app.icon,
          silicaIcon: app.silicaIcon.isEmpty ? null : app.silicaIcon,
          terminal: app.terminal,
          appId: app.id,
        ),
  };
}

/// The desktop file id other desktops know an app of the registry by.
String desktopIdOf(SilicaInstalledApp app) =>
    app.kind == SilicaInstalledAppKind.bundle ||
        app.kind == SilicaInstalledAppKind.appimage ||
        (app.kind == SilicaInstalledAppKind.system && app.desktopFile.isEmpty)
    ? 'silica-bundles-${app.id}.desktop'
    : '${app.id}.desktop';

/// A .desktop entry (text); null if it is not a launchable app or it is hidden.
DesktopApp? parseDesktopApp(String id, String text, {String? locale}) {
  locale ??= l10n.localeName;
  final values = <String, String>{};
  var inEntry = false;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('[')) {
      inEntry = line == '[Desktop Entry]';
      continue;
    }
    if (!inEntry || line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    values[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  if (values['Type'] != 'Application') return null;
  if (values['NoDisplay'] == 'true' || values['Hidden'] == 'true') return null;
  final exec = values['Exec'];
  final name = values['Name[$locale]'] ?? values['Name'];
  if (exec == null || exec.isEmpty || name == null) return null;
  return DesktopApp(
    id: id,
    name: name,
    exec: exec,
    mimeTypes: [
      for (final t in (values['MimeType'] ?? '').split(';'))
        if (t.trim().isNotEmpty) t.trim(),
    ],
    icon: values['Icon'],
    silicaIcon: values['X-Silica-Icon'],
    terminal: values['Terminal'] == 'true',
  );
}

/// The choices of `mimeapps.list`, merged in precedence order.
class MimeApps {
  final Map<String, List<String>> defaults = {};
  final Map<String, List<String>> added = {};
  final Map<String, Set<String>> removed = {};

  /// Adds a file (the first ones read take precedence).
  void addFile(String text) {
    String? section;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('[')) {
        section = line;
        continue;
      }
      final eq = line.indexOf('=');
      if (eq <= 0 || line.startsWith('#')) continue;
      final type = line.substring(0, eq).trim();
      final ids = [
        for (final id in line.substring(eq + 1).split(';'))
          if (id.trim().isNotEmpty) id.trim(),
      ];
      switch (section) {
        case '[Default Applications]':
          defaults.putIfAbsent(type, () => []).addAll(ids);
        case '[Added Associations]':
          added.putIfAbsent(type, () => []).addAll(ids);
        case '[Removed Associations]':
          removed.putIfAbsent(type, () => {}).addAll(ids);
      }
    }
  }
}

/// The apps and associations of the system and of the user.
class AppRegistry {
  AppRegistry(this.apps, this.mimeApps, this.mime);

  /// From the system files: applications/ in the XDG data directories (the first wins), and the
  /// `mimeapps.list` files of configuration and data (specification, "File name and location").
  factory AppRegistry.load({Map<String, String>? env, MimeDatabase? mime}) {
    final e = env ?? Platform.environment;
    final apps = <String, DesktopApp>{};
    final dataDirs = xdgDataDirs(e);
    for (final dir in dataDirs) {
      final root = Directory('$dir/applications');
      if (!root.existsSync()) continue;
      try {
        for (final file in root.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.desktop')) continue;
          final id = file.path
              .substring(root.path.length + 1)
              .replaceAll('/', '-');
          if (apps.containsKey(id)) continue;
          try {
            final app = parseDesktopApp(id, file.readAsStringSync());
            if (app != null) apps[id] = app;
          } on FileSystemException {
            continue;
          } on FormatException {
            continue;
          }
        }
      } on FileSystemException {
        continue;
      }
    }
    return AppRegistry(
      apps,
      loadMimeApps(e),
      mime ?? MimeDatabase.load(env: env),
    );
  }

  /// The registry's apps (Launch Services) with the same associations.
  factory AppRegistry.withInstalled(
    Iterable<SilicaInstalledApp> installed, {
    Map<String, String>? env,
    MimeDatabase? mime,
  }) {
    final e = env ?? Platform.environment;
    return AppRegistry(
      appsFromInstalled(installed),
      loadMimeApps(e),
      mime ?? MimeDatabase.load(env: env),
    );
  }

  /// From the registry when it runs (bundles and AppImages included), else from the files.
  static Future<AppRegistry> current({
    Map<String, String>? env,
    MimeDatabase? mime,
  }) async {
    final installed = await SilicaApps.list();
    return installed == null
        ? AppRegistry.load(env: env, mime: mime)
        : AppRegistry.withInstalled(installed, env: env, mime: mime);
  }

  final Map<String, DesktopApp> apps;
  final MimeApps mimeApps;
  final MimeDatabase mime;

  List<String> _typeChain(String type) => [type, ...mime.parentsOf(type)];

  /// The default app for a type: `Default Applications` for the type and then for its parents;
  /// otherwise the first added or installed app that opens it.
  DesktopApp? defaultFor(String type) {
    for (final t in _typeChain(type)) {
      for (final id in mimeApps.defaults[t] ?? const <String>[]) {
        final app = apps[id];
        if (app != null && !(mimeApps.removed[t]?.contains(id) ?? false))
          return app;
      }
    }
    return appsFor(type).firstOrNull;
  }

  /// The apps that open a type (or one of its parents), without the removed ones; first those added
  /// in `mimeapps.list`, then the others by name.
  List<DesktopApp> appsFor(String type) {
    final out = <DesktopApp>[];
    final seen = <String>{};
    for (final t in _typeChain(type)) {
      final removed = mimeApps.removed[t] ?? const <String>{};
      for (final id in mimeApps.added[t] ?? const <String>[]) {
        final app = apps[id];
        if (app != null && !removed.contains(id) && seen.add(id)) out.add(app);
      }
      final declared = [
        for (final app in apps.values)
          if (app.mimeTypes.contains(t) && !removed.contains(app.id)) app,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final app in declared) {
        if (seen.add(app.id)) out.add(app);
      }
    }
    return out;
  }
}

/// The `mimeapps.list` files of configuration and data, merged (specification, "File name and
/// location").
MimeApps loadMimeApps(Map<String, String> e) {
  final mimeApps = MimeApps();
  final dataDirs = xdgDataDirs(e);
  final home = e['HOME'] ?? '/';
  final config = e['XDG_CONFIG_HOME'];
  final configHome = config == null || config.isEmpty
      ? '$home/.config'
      : config;
  final configDirs = (e['XDG_CONFIG_DIRS'] ?? '/etc/xdg').split(':');
  for (final path in [
    '$configHome/mimeapps.list',
    for (final d in configDirs)
      if (d.isNotEmpty) '$d/mimeapps.list',
    for (final d in dataDirs) '$d/applications/mimeapps.list',
  ]) {
    try {
      mimeApps.addFile(File(path).readAsStringSync());
    } on FileSystemException {
      continue;
    } on FormatException {
      continue;
    }
  }
  return mimeApps;
}

/// The `Exec` command line to open `paths` (field codes: %f %F %u %U, %i %c %k; %d %D %n %N %v %m
/// are deprecated and dropped; %% is %). The quoting rules of the specification are respected.
List<String> execArguments(
  DesktopApp app,
  List<String> paths, {
  String? desktopFile,
}) {
  final words = _splitExec(app.exec);
  final out = <String>[];
  var usedFiles = false;
  for (final word in words) {
    switch (word) {
      case '%f' || '%u':
        if (paths.isNotEmpty) out.add(paths.first);
        usedFiles = true;
      case '%F' || '%U':
        out.addAll(paths);
        usedFiles = true;
      case '%i':
        if (app.icon != null) out.addAll(['--icon', app.icon!]);
      case '%c':
        out.add(app.name);
      case '%k':
        if (desktopFile != null) out.add(desktopFile);
      case '%d' || '%D' || '%n' || '%N' || '%v' || '%m':
        break;
      default:
        out.add(
          word
              .replaceAll('%%', '\u0000')
              .replaceAllMapped(RegExp('%[a-zA-Z]'), (_) => '')
              .replaceAll('\u0000', '%'),
        );
    }
  }
  // An app without field codes still gets the file at the end.
  if (!usedFiles) out.addAll(paths);
  return out.where((w) => w.isNotEmpty).toList();
}

List<String> _splitExec(String exec) {
  final out = <String>[];
  final current = StringBuffer();
  var quoted = false;
  var started = false;
  for (var i = 0; i < exec.length; i++) {
    final c = exec[i];
    if (quoted) {
      if (c == '\\' && i + 1 < exec.length) {
        current.write(exec[++i]);
      } else if (c == '"') {
        quoted = false;
      } else {
        current.write(c);
      }
    } else if (c == '"') {
      quoted = true;
      started = true;
    } else if (c == ' ' || c == '\t') {
      if (started || current.isNotEmpty) out.add(current.toString());
      current.clear();
      started = false;
    } else {
      current.write(c);
      started = true;
    }
  }
  if (started || current.isNotEmpty) out.add(current.toString());
  return out;
}

/// Launches an app on some files, detached from Mustache. An error (missing program) is a message.
Future<String?> launchApp(DesktopApp app, List<String> paths) async {
  // Through the registry: the same command line every launcher uses, bundles and AppImages
  // through their trust check and sandbox.
  if (app.appId case final id?) {
    final pid = await SilicaApps.open(
      id,
      uris: [for (final p in paths) Uri.file(p).toString()],
    );
    if (pid != null) return null;
  }
  final args = execArguments(app, paths);
  if (args.isEmpty) return l10n.appHasNoCommand(app.name);
  try {
    await startDetached(args.first, args.skip(1).toList());
    return null;
  } on ProcessException catch (e) {
    return l10n.appCantOpen(app.name, e.message);
  }
}

final Map<String, String?> _comments = {};

/// The description of a MIME type in the language (`<comment xml:lang="it">` of `mime/<type>.xml`),
/// or the one without a language; null if the type has no file.
String? mimeComment(String type, {String? locale, Map<String, String>? env}) {
  locale ??= l10n.localeName;
  final key = '$locale $type';
  // Cached only with the process environment (tests pass others).
  if (env == null && _comments.containsKey(key)) return _comments[key];
  String? found;
  for (final dir in xdgDataDirs(env ?? Platform.environment)) {
    final file = File('$dir/mime/$type.xml');
    if (!file.existsSync()) continue;
    try {
      final text = file.readAsStringSync();
      final localized = RegExp(
        '<comment xml:lang="$locale">([^<]*)</comment>',
      ).firstMatch(text);
      final plain = RegExp('<comment>([^<]*)</comment>').firstMatch(text);
      found = _unescape((localized ?? plain)?.group(1));
      if (found != null) break;
    } on FileSystemException {
      continue;
    }
  }
  if (env == null) _comments[key] = found;
  return found;
}

String? _unescape(String? s) => s
    ?.replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');
