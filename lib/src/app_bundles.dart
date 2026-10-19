// App bundles and disk images (silica-os docs/app-bundles.md, mustache#6): the Applications
// view merges /Applications, ~/Applications and the system's apps; a `Name.app` bundle is one
// item that opens the app; a `.sxv` disk image attaches as a volume (Volumes1) and shows its
// window; dragging an app into Applications installs it (copied, in quarantine, through polkit
// when the folder is not writable).

import 'dart:io';
import 'dart:ui' show Offset, Size;

import 'package:silica_ui/silica_ui.dart';

import 'external.dart';
import 'model.dart';
import 'xattr.dart';

/// The Applications folder of every user (a link to /var/Applications on Silica OS).
const String applicationsPath = '/Applications';

/// The quarantine attribute (docs/app-bundles.md § 6).
const String quarantineAttribute = 'user.silica.quarantine';

/// Flag of a quarantine mark: copied out of a disk image.
const int quarantineFromVolume = 0x0002;

/// The privileged helper of /Applications (run through pkexec).
const String applicationsHelper =
    '/usr/libexec/silica/silica-applications-helper';

/// Whether `path` is an app bundle: a `Name.app` folder with `Contents/Info.toml`.
bool isAppBundle(String path) =>
    path.endsWith('.app') &&
    File('$path/Contents/Info.toml').existsSync() &&
    FileSystemEntity.isDirectorySync(path);

/// Whether `path` is the Applications folder: its link, its target, or a link to it (the
/// alias in a disk image).
bool isApplicationsFolder(String path) {
  bool named(String p) {
    final trimmed = p.endsWith('/') && p.length > 1
        ? p.substring(0, p.length - 1)
        : p;
    return trimmed == applicationsPath || trimmed == '/var/Applications';
  }

  if (named(path)) return true;
  try {
    return named(Directory(path).resolveSymbolicLinksSync());
  } on FileSystemException {
    return false;
  }
}

/// The folders the Applications view merges, most important first: the user's, then every
/// user's (`/Applications` itself is the one listed), then the system's.
List<String> mergedApplicationFolders(Map<String, String> env) => [
  if (env['HOME'] case final home? when home.isNotEmpty) '$home/Applications',
  '/usr/Applications',
  '/var/lib/silica-dev/Applications',
];

/// The entries of the Applications view: those of /Applications ([own]) and, after them, the
/// apps of the other folders whose names are not taken yet. The system's apps stay in their
/// folder (they cannot be moved to the Trash: the folder is read-only).
List<Entry> mergeApplications(
  List<Entry> own,
  Map<String, String> env, {
  bool showHidden = false,
  Iterable<SilicaInstalledApp> flatpaks = const [],
}) {
  final names = {for (final e in own) e.name};
  final out = [...own];
  for (final folder in mergedApplicationFolders(env)) {
    if (!Directory(folder).existsSync()) continue;
    for (final e in listDirectory(folder, showHidden: showHidden).entries) {
      if (names.add(e.name)) out.add(e);
    }
  }
  // The Flatpak apps, as items named after the app (mustache#32), unless a bundle has the name.
  for (final app in flatpaks) {
    final entry = flatpakEntry(app);
    if (entry != null &&
        names.add('${entry.name}.app') &&
        names.add(entry.name)) {
      out.add(entry);
    }
  }
  return out;
}

/// The item of a Flatpak app in the Applications view: its exported desktop entry (the icon
/// comes from it), named after the app. Null when the registry gave no entry file.
Entry? flatpakEntry(SilicaInstalledApp app) {
  final file = app.desktopFile.isNotEmpty ? app.desktopFile : app.path;
  if (app.kind != SilicaInstalledAppKind.flatpak ||
      !file.endsWith('.desktop')) {
    return null;
  }
  final stat = FileStat.statSync(file);
  if (stat.type == FileSystemEntityType.notFound) return null;
  return Entry(
    name: app.name,
    path: file,
    isDirectory: false,
    size: 0,
    modified: stat.modified,
  );
}

/// The Flatpak apps of the registry, by the path of their item ([flatpakEntry]).
Map<String, SilicaInstalledApp> flatpakItems(
  Iterable<SilicaInstalledApp> apps,
) => {
  for (final app in apps)
    if (flatpakEntry(app) case final entry?) entry.path: app,
};

/// A free name for a copy of `name` in `folder` ("Keep Both"): `Name 2.app`, `Name 3.app`…
String keepBothName(String folder, String name) {
  final dot = name.endsWith('.app') ? name.length - 4 : name.length;
  final stem = name.substring(0, dot);
  final suffix = name.substring(dot);
  bool taken(String n) =>
      FileSystemEntity.typeSync('$folder/$n', followLinks: false) !=
      FileSystemEntityType.notFound;
  for (var n = 2; n < 10000; n++) {
    final candidate = '$stem $n$suffix';
    if (!taken(candidate)) return candidate;
  }
  return '$stem ${DateTime.now().millisecondsSinceEpoch}$suffix';
}

/// The folder where disk images are mounted (`$XDG_RUNTIME_DIR/silica-volumes`).
String? volumesFolder(Map<String, String> env) {
  final runtime = env['XDG_RUNTIME_DIR'];
  return runtime == null || runtime.isEmpty ? null : '$runtime/silica-volumes';
}

/// The volume whose mount point is `path` or contains it.
SilicaVolume? volumeOf(String path, List<SilicaVolume> volumes) {
  for (final v in volumes) {
    if (path == v.mountpoint || path.startsWith('${v.mountpoint}/')) return v;
  }
  return null;
}

/// The icon positions of a disk image's window (centre x, top y): those its layout names, and
/// the other items in a row under them, so that nothing lands on top of the layout.
Map<String, Offset> volumePositions(
  List<Entry> entries,
  SilicaVolumeWindow layout,
  double side,
) {
  final out = <String, Offset>{};
  final rest = <Entry>[];
  for (final e in entries) {
    final item = layout.items.where((i) => i.name == e.name).firstOrNull;
    if (item == null) {
      rest.add(e);
    } else {
      out[e.path] = Offset(item.x, item.y - side / 2);
    }
  }
  final bottom = layout.items.fold<double>(0, (m, i) => i.y > m ? i.y : m);
  final step = side + 40;
  for (final (i, e) in rest.indexed) {
    out[e.path] = Offset(step / 2 + 20 + i * step, bottom + side / 2 + 40);
  }
  return out;
}

/// The height of a disk image window's title bar (kit `Apps/Mustache/Volume Window`).
const double volumeTitleBarHeight = 40;

/// The window size for a disk image's layout: its content (width × height, in pt; the default
/// 540 × 380) under the 40 pt title bar; null when the layout gives no size.
Size? volumeWindowSize(SilicaVolumeWindow layout) {
  if (layout.width <= 0 || layout.height <= 0) return null;
  return Size(layout.width, layout.height + volumeTitleBarHeight);
}

/// Starts the app of a bundle (through silica-launch: its trust check and sandbox).
Future<void> launchBundle(String path, {List<String> files = const []}) =>
    startDetached('silica-launch', [path, ...files]);

/// The quarantine mark for a copy out of the disk image `image`.
String volumeQuarantine(String image, {DateTime? now}) {
  final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final origin = Uri.file(image).toString().replaceAll(';', '%3B');
  return '1;${quarantineFromVolume.toRadixString(16).padLeft(4, '0')};'
      '${seconds.toRadixString(16)};dev.frascella.Mustache;$origin';
}

/// Why an install did not happen.
enum InstallError { exists, denied, failed }

/// Copies the bundle `source` into the folder `target` (Applications or another), marked with
/// `quarantine` when given. Where the user cannot write (a standard user and /Applications) the
/// copy goes through the polkit helper: the user copies into a staging folder the helper made,
/// the helper takes it over and moves it in. Returns the installed path, or the error.
Future<(String?, InstallError?)> installBundle(
  String source,
  String target, {
  String? quarantine,
  bool replace = false,
  String? name,
}) async {
  name ??= displayName(source);
  final destination = '$target/$name';
  final exists =
      FileSystemEntity.typeSync(destination, followLinks: false) !=
      FileSystemEntityType.notFound;
  if (exists && !replace) return (null, InstallError.exists);
  if (_writable(target)) {
    final staging = '$target/.$name.installing';
    await _remove(staging);
    if (!await _copy(source, staging)) {
      await _remove(staging);
      return (null, InstallError.failed);
    }
    if (quarantine != null)
      writeAttribute(staging, quarantineAttribute, quarantine);
    try {
      if (exists) await _remove(destination);
      Directory(staging).renameSync(destination);
    } on FileSystemException {
      await _remove(staging);
      return (null, InstallError.failed);
    }
    return (destination, null);
  }
  if (!isApplicationsFolder(target)) return (null, InstallError.denied);
  // Through polkit: begin (a staging folder of ours), copy, commit.
  final begin = await _helper(['begin']);
  if (begin == null) return (null, InstallError.denied);
  final staging = begin.trim();
  if (!await _copy(source, '$staging/$name')) {
    return (null, InstallError.failed);
  }
  if (quarantine != null) {
    writeAttribute('$staging/$name', quarantineAttribute, quarantine);
  }
  final commit = await _helper(['commit', staging, if (replace) '--replace']);
  if (commit == null) return (null, InstallError.failed);
  return ('$applicationsPath/$name', null);
}

/// Removes an app of /Applications the user cannot write (through polkit). True when done.
Future<bool> removeFromApplications(String path) async =>
    await _helper(['remove', displayName(path)]) != null;

bool _writable(String folder) {
  try {
    final probe = File('$folder/.mustache-write-${pid.toString()}');
    probe.writeAsStringSync('');
    probe.deleteSync();
    return true;
  } on FileSystemException {
    return false;
  }
}

Future<bool> _copy(String from, String to) async {
  try {
    final result = await Process.run('cp', [
      '-a',
      '--no-preserve=ownership',
      from,
      to,
    ]);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<void> _remove(String path) async {
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      Directory(path).deleteSync(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      File(path).deleteSync();
    }
  } on FileSystemException {
    // Left for the next attempt.
  }
}

/// Runs the helper through pkexec; its output, or null when refused or failed.
Future<String?> _helper(List<String> args) async {
  if (startsNothing) return null;
  try {
    final result = await Process.run('pkexec', [applicationsHelper, ...args]);
    return result.exitCode == 0 ? '${result.stdout}' : null;
  } on ProcessException {
    return null;
  }
}

/// Whether `path` is one of the system's apps (read-only, part of the image).
bool isSystemApp(String path) =>
    path.startsWith('/usr/') ||
    path.startsWith('/var/lib/silica-dev/Applications/');

/// The id in a bundle's `Info.toml` (`id = "…"`), or null.
String? bundleId(String path) {
  try {
    for (final line in File('$path/Contents/Info.toml').readAsLinesSync()) {
      final match = RegExp(r'^\s*id\s*=\s*"([^"]+)"').firstMatch(line);
      if (match != null) return match.group(1);
    }
  } on FileSystemException {
    return null;
  }
  return null;
}

/// The version in a bundle's `Info.toml` (`version = "…"`), or null.
String? bundleVersion(String path) {
  try {
    for (final line in File('$path/Contents/Info.toml').readAsLinesSync()) {
      final match = RegExp(r'^\s*version\s*=\s*"([^"]+)"').firstMatch(line);
      if (match != null) return match.group(1);
    }
  } on FileSystemException {
    return null;
  }
  return null;
}

/// The live processes of the app `id` in the session's app registry
/// (`$XDG_RUNTIME_DIR/silica-apps/<id>.<pid>.sock`).
List<int> appPids(String id, Map<String, String> env) {
  final runtime = env['XDG_RUNTIME_DIR'];
  if (runtime == null || runtime.isEmpty) return const [];
  final out = <int>[];
  try {
    for (final e in Directory('$runtime/silica-apps').listSync()) {
      final name = e.path.split('/').last;
      if (!name.startsWith('$id.') || !name.endsWith('.sock')) continue;
      final pid = int.tryParse(
        name.substring(id.length + 1, name.length - '.sock'.length),
      );
      if (pid != null && Directory('/proc/$pid').existsSync()) out.add(pid);
    }
  } on FileSystemException {
    return const [];
  }
  return out;
}

/// Asks the app `id` to quit (SIGTERM to its processes) and waits until they are gone, at most
/// `wait`; true when it quit.
Future<bool> quitApp(
  String id,
  Map<String, String> env, {
  Duration wait = const Duration(seconds: 5),
}) async {
  for (final pid in appPids(id, env)) {
    Process.killPid(pid);
  }
  final until = DateTime.now().add(wait);
  while (DateTime.now().isBefore(until)) {
    if (appPids(id, env).isEmpty) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return appPids(id, env).isEmpty;
}

/// Whether `path` is a type-2 AppImage (`*.AppImage`, an ELF with `AI\x02` at offset 8).
bool isAppImage(String path) {
  if (!path.toLowerCase().endsWith('.appimage')) return false;
  try {
    final file = File(path).openSync();
    try {
      final head = file.readSync(11);
      return head.length == 11 &&
          head[0] == 0x7f &&
          head[1] == 0x45 &&
          head[2] == 0x4c &&
          head[3] == 0x46 &&
          head[8] == 0x41 &&
          head[9] == 0x49 &&
          head[10] == 0x02;
    } finally {
      file.closeSync();
    }
  } on FileSystemException {
    return false;
  }
}

/// Runs an AppImage in the sandbox from now on, or not (Trust1.SetSandbox); true when done.
Future<bool> setAppImageSandbox(String path, bool on) async {
  try {
    final reply = await SilicaDBus.instance.call(
      destination: 'dev.frascella.Silica',
      path: '/dev/frascella/Silica/Trust1',
      interface: 'dev.frascella.Silica.Trust1',
      method: 'SetSandbox',
      signature: 'sb',
      args: [path, on],
    );
    return reply.firstOrNull == true;
  } on Exception {
    return false;
  }
}

/// Whether the app `id` runs now: the session's app registry has a socket of a live process
/// (`$XDG_RUNTIME_DIR/silica-apps/<id>.<pid>.sock`).
bool appRunning(String id, Map<String, String> env) {
  final runtime = env['XDG_RUNTIME_DIR'];
  if (runtime == null || runtime.isEmpty) return false;
  try {
    for (final e in Directory('$runtime/silica-apps').listSync()) {
      final name = e.path.split('/').last;
      if (!name.startsWith('$id.') || !name.endsWith('.sock')) continue;
      final pid = name.substring(id.length + 1, name.length - '.sock'.length);
      if (int.tryParse(pid) != null && Directory('/proc/$pid').existsSync()) {
        return true;
      }
    }
  } on FileSystemException {
    return false;
  }
  return false;
}

/// Whether the folder `path` can be written by this user.
bool folderWritable(String path) => _writable(path);
