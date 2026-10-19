// Apps and disk images in the window (mustache#6, silica-os docs/app-bundles.md): opening an app
// bundle starts it, opening a `.sxv` disk image attaches it (license, signature) and shows its
// window, dropping an app into Applications installs it (in quarantine when it comes from a
// disk image, then the offer to eject), volumes are ejected from the sidebar.

part of 'window.dart';

extension _Apps on _MustacheWindowState {
  /// The attached volumes, from silica-daemon's Volumes1.
  Future<void> _loadVolumes() async {
    final volumes = await SilicaVolumes.list();
    if (!mounted) return;
    _update(() => _volumes = volumes);
  }

  /// The sidebar rows of the attached volumes.
  List<Place> get _volumePlaces => [
    for (final v in _volumes) Place(v.name, v.mountpoint, PlaceKind.volume),
  ];

  /// The Applications row, when the folder exists.
  Place? get _applicationsPlace => Directory(applicationsPath).existsSync()
      ? Place(
          l10n.sidebarApplications,
          applicationsPath,
          PlaceKind.applications,
        )
      : null;

  /// The volume whose window this is: the current folder is its mount point.
  SilicaVolume? get _volumeRoot {
    final v = volumeOf(_history.current, _volumes);
    return v != null && v.mountpoint == _history.current ? v : null;
  }

  /// Opens a `.sxv` disk image: verified and attached by the daemon (the license first), then
  /// shown.
  Future<void> _openDiskImage(String image, {bool accepted = false}) async {
    final info = await SilicaVolumes.inspect(image);
    if (!mounted) return;
    final name = info?.name ?? displayName(image);
    if (info != null && info.license.isNotEmpty && !accepted) {
      _showAlert(
        MustacheAlert(
          opaque: true,
          icon: _appIcon,
          title: l10n.licenseTitle(name),
          message: info.license,
          buttons: [
            AlertButton(
              l10n.licenseDisagree,
              role: AlertRole.cancel,
              onPressed: _closeAlert,
            ),
            AlertButton(
              l10n.licenseAgree,
              role: AlertRole.primary,
              onPressed: () {
                _closeAlert();
                unawaited(_openDiskImage(image, accepted: true));
              },
            ),
          ],
        ),
      );
      return;
    }
    final (mount, error) = await SilicaVolumes.attach(
      image,
      acceptLicense: accepted,
    );
    if (!mounted) return;
    if (mount == null) {
      _showError(switch (error) {
        SilicaVolumeError.badSignature => l10n.volumeBadSignature(name),
        SilicaVolumeError.unsigned => l10n.volumeUnsigned(name),
        SilicaVolumeError.revoked => l10n.volumeRevoked(name),
        _ => l10n.volumeFailed(name),
      });
      return;
    }
    await _loadVolumes();
    if (!mounted) return;
    _navigate(mount);
    // A dialog stays a dialog: only a browser window becomes the image's window.
    if (widget.dialog == null && volumeOf(mount, _volumes) != null) {
      _setVolumeWindow(true);
    }
  }

  /// Makes this window the disk image's window, or gives it its chrome back: the title bar is
  /// 40 pt (Ossido places the window buttons in it) and the window takes the layout's size
  /// (`.silica-window.toml` width × height under the title bar, 540 × 380 by default).
  void _setVolumeWindow(bool on) {
    if (_volumeWindow == on) return;
    _update(() => _volumeWindow = on);
    final view = View.maybeOf(context)?.viewId ?? 0;
    unawaited(
      SilicaWindow.setFullSizeContent(
        on ? volumeTitleBarHeight : AmalfiToolbarMetrics.toolbarHeight,
        viewId: view,
      ),
    );
    final volume = _volumeRoot;
    if (on && volume != null) {
      final size = volumeWindowSize(volume.window);
      if (size != null) unawaited(SilicaWindow.setSize(size, viewId: view));
    }
  }

  /// The disk image volume icon in alerts (silica-icons `files/volume-disk-image`).
  Widget? get _volumeIcon {
    final dir = widget.iconsDir;
    if (dir == null || dir.isEmpty) return null;
    final dark = AmalfiTheme.of(context).isDark;
    final file = File(
      '$dir/files/volume-disk-image/${dark ? 'icon-dark' : 'icon'}.png',
    );
    return file.existsSync() ? Image.file(file, width: 56, height: 56) : null;
  }

  /// The title bar of a disk image's window (kit `Apps/Mustache/Volume Window`): 40 tall, the
  /// `drive` glyph 16, 4, and the volume's name in the title style, centred; it moves the window.
  Widget _volumeTitleBar() {
    final colors = AmalfiTheme.of(context).colors;
    final name = _volumeRoot?.name ?? displayName(_history.current);
    return WindowDragArea(
      child: SizedBox(
        key: const ValueKey('volume title bar'),
        height: volumeTitleBarHeight,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmalfiSymbol('drive', size: 16, color: colors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AmalfiType.bodyEmphasis(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ejects a volume from its sidebar row; the window leaves it first.
  Future<void> _eject(Place place) async {
    if (volumeOf(_history.current, [
          for (final v in _volumes)
            if (v.mountpoint == place.path) v,
        ]) !=
        null) {
      _navigate(homeOf(widget.iconsEnv));
    }
    final ok = await SilicaVolumes.detach(place.path);
    if (!mounted) return;
    if (!ok) {
      _showError(l10n.volumeBusy(place.label));
      return;
    }
    await _loadVolumes();
  }

  /// Whether a drop on `destination` is an install: the destination is Applications (or the
  /// alias of it in a disk image) and everything dropped is an app bundle.
  bool _isInstall(List<String> paths, String destination) {
    String real;
    try {
      real = File(destination).resolveSymbolicLinksSync();
    } on FileSystemException {
      real = destination;
    }
    return isApplicationsFolder(real) &&
        paths.isNotEmpty &&
        paths.every(isAppBundle);
  }

  /// Installs app bundles into Applications.
  Future<void> _installApps(
    List<String> bundles, {
    bool replace = false,
    bool keepBoth = false,
  }) async {
    SilicaVolume? fromVolume;
    for (final source in bundles) {
      final volume = volumeOf(source, _volumes);
      fromVolume ??= volume;
      // From a disk image: marked as coming from it; otherwise the source's own mark travels.
      final quarantine = volume != null
          ? volumeQuarantine(volume.image)
          : readAttribute(source, quarantineAttribute);
      final (installed, error) = await installBundle(
        source,
        applicationsPath,
        quarantine: quarantine,
        replace: replace,
        // "Keep Both": the copy takes the next free name (Name 2.app).
        name: keepBoth
            ? keepBothName(applicationsPath, displayName(source))
            : null,
      );
      if (!mounted) return;
      final name = displayName(source);
      if (error == InstallError.exists) {
        _showAlert(
          MustacheAlert(
            opaque: true,
            icon: _appIcon,
            title: l10n.installExists(name.replaceAll(RegExp(r'\.app$'), '')),
            buttons: [
              AlertButton(
                l10n.installKeepBoth,
                onPressed: () {
                  _closeAlert();
                  unawaited(_installApps([source], keepBoth: true));
                },
              ),
              AlertButton(
                l10n.installStop,
                role: AlertRole.cancel,
                onPressed: _closeAlert,
              ),
              AlertButton(
                l10n.installReplace,
                role: AlertRole.primary,
                onPressed: () {
                  _closeAlert();
                  unawaited(_installApps([source], replace: true));
                },
              ),
            ],
          ),
        );
        return;
      }
      if (installed == null) {
        _showError(l10n.installFailed(name));
        return;
      }
    }
    final volume = fromVolume;
    if (volume == null || !mounted) return;
    // From a disk image: the offer to eject it and throw the image away (kit
    // `Alerts/Gatekeeper/Eject`: Move to Trash, then Keep, the default).
    final installedName = displayName(
      bundles.first,
    ).replaceAll(RegExp(r'\.app$'), '');
    _showAlert(
      MustacheAlert(
        opaque: true,
        icon: _volumeIcon ?? _appIcon,
        sideBySide: true,
        title: l10n.installEject(volume.name),
        message: l10n.installedInApplications(installedName),
        buttons: [
          AlertButton(
            l10n.moveToTrash,
            onPressed: () async {
              _closeAlert();
              await _eject(
                Place(volume.name, volume.mountpoint, PlaceKind.volume),
              );
              final result = Trash.forUser(
                widget.iconsEnv ?? Platform.environment,
              ).put(volume.image);
              if (result.error != null && mounted) {
                _showError(l10n.volumeFailed(volume.name), result.error);
              }
            },
          ),
          AlertButton(
            l10n.installKeep,
            role: AlertRole.primary,
            onPressed: _closeAlert,
          ),
        ],
      ),
    );
  }
}

/// The home folder of the environment.
String homeOf(Map<String, String>? env) =>
    (env ?? Platform.environment)['HOME'] ?? '/';
