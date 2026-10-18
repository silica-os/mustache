// The window in dialog mode (Open and Save for the portal, docs/spec/dialogs.md): at the top, for Save,
// the name field; at the bottom Cancel and the accept button (accent colored, disabled without a
// valid choice). Double click on a file and Return accept; Esc cancels.

part of 'window.dart';

/// The name row of the Save panel, below the toolbar.
const double saveBarHeight = 52;

/// The footer with Cancel and the accept button (kit `Dialogs/Dialog/Open Panel` and
/// `Dialogs/Footer/Open`): 12 pt below what is above it (here the divider), the 28 pt buttons
/// 8 pt apart against the right, 20 pt from the sides and from the bottom of the panel.
const double dialogFooterTop = 12;
const double dialogFooterBottom = 20;
const double dialogFooterSide = 20;
const double dialogFooterGap = 8;
const double dialogButtonHeight = 28;

/// The Cancel and accept row at the bottom: the divider, then the footer.
const double dialogButtonsHeight =
    1 + dialogFooterTop + dialogButtonHeight + dialogFooterBottom;

extension _Dialog on _MustacheWindowState {
  DialogOptions get _dialogOptions => widget.dialog!;

  /// The items the dialog would return now.
  List<String> get _dialogChoice {
    final d = _dialogOptions;
    if (d.save) {
      final name = _saveName.text.trim();
      if (name.isEmpty || name.contains('/')) return const [];
      return ['${_history.current}/$name'];
    }
    final chosen = [
      for (final e in _selection)
        if (d.directory == e.isDirectory) e.path,
    ];
    // For folders, without a choice the open one counts.
    if (chosen.isEmpty && d.directory) return [_history.current];
    return d.multiple ? chosen : chosen.take(1).toList();
  }

  void _finish(List<String> paths) =>
      (widget.onDialogFinish ?? finishDialog)(paths);

  void _acceptDialog() {
    final paths = _dialogChoice;
    if (paths.isEmpty) return;
    if (_dialogOptions.save && entryAt(paths.single) != null) {
      // A file with the same name: ask before replacing it.
      _update(
        () => _alert = MustacheAlert(
          opaque: true,
          icon: _appIcon,
          title: l10n.replaceQuestion(displayName(paths.single)),
          message: l10n.replaceDetail,
          sideBySide: true,
          buttons: [
            AlertButton(
              l10n.cancel,
              role: AlertRole.cancel,
              onPressed: _closeAlert,
            ),
            AlertButton(
              l10n.replace,
              role: AlertRole.destructive,
              onPressed: () {
                _closeAlert();
                _finish(paths);
              },
            ),
          ],
        ),
      );
      return;
    }
    _finish(paths);
  }

  /// The name row for Save: the label and the name field, 20 from the edges.
  Widget _saveBar() {
    final colors = AmalfiTheme.of(context).colors;
    return SizedBox(
      key: const ValueKey('name row'),
      height: saveBarHeight,
      child: Row(
        children: [
          const SizedBox(width: 20),
          SizedBox(
            width: 96,
            child: Text(
              l10n.saveAs,
              textAlign: TextAlign.right,
              style: AmalfiType.body(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          KeyedSubtree(
            key: const ValueKey('dialog name field'),
            child: AmalfiTextField(
              controller: _saveName,
              focusNode: _saveFocus,
              width: 232,
              semanticLabel: l10n.saveAs,
              onChanged: (_) => _update(() {}),
              onSubmitted: (_) => _acceptDialog(),
            ),
          ),
        ],
      ),
    );
  }

  /// At the bottom: Cancel and the accept button, 20 from the edge and 8 apart, over a separator.
  Widget _dialogButtons() {
    final enabled = _dialogChoice.isNotEmpty;
    final colors = AmalfiTheme.of(context).colors;
    return SizedBox(
      key: const ValueKey('dialog buttons'),
      height: dialogButtonsHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const ValueKey('dialog divider'),
            height: 1,
            child: ColoredBox(color: colors.lineSeparator),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              dialogFooterSide,
              dialogFooterTop,
              dialogFooterSide,
              dialogFooterBottom,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: dialogFooterGap,
              children: [
                KeyedSubtree(
                  key: ValueKey('dialog ${l10n.cancel}'),
                  child: AmalfiPushButton(
                    label: l10n.cancel,
                    onPressed: () => _finish(const []),
                  ),
                ),
                KeyedSubtree(
                  key: ValueKey('dialog ${_dialogOptions.acceptLabel}'),
                  child: AmalfiPushButton(
                    label: _dialogOptions.acceptLabel,
                    variant: AmalfiPushButtonVariant.primary,
                    onPressed: enabled ? _acceptDialog : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
