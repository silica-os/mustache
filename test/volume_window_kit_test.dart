// A disk image window against the Amalfi kit (silica-design cbf75649,
// `Apps/Mustache/Volume Window/<Default Background|Custom Background>` and `Apps/Mustache/Volume
// Item/Label Plate`): the icons of 128 where the layout puts them, the alias badge of the
// Applications link 32 at (4, 92) of its icon, and the names on plates on a custom background.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/app_bundles.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  final lemon = Entry(
    name: 'Lemon.app',
    path: '/v/Lemon.app',
    isDirectory: true,
    size: 0,
    modified: DateTime(2026),
  );
  final applications = Entry(
    name: 'Applications',
    path: '/v/Applications',
    isDirectory: true,
    size: 0,
    modified: DateTime(2026),
    isLink: true,
  );
  // The kit's layout: Lemon at (140, 230), Applications at (400, 230) (icon centres).
  const layout = SilicaVolumeWindow(
    items: [
      SilicaVolumeItem('Lemon.app', 140, 230),
      SilicaVolumeItem('Applications', 400, 230),
    ],
  );

  Future<void> pump(WidgetTester tester, {required bool plates}) async {
    tester.view.physicalSize = const Size(540, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AmalfiTheme(
          brightness: Brightness.light,
          child: IconView(
            entries: [lemon, applications],
            selected: const {},
            onTap: (_) {},
            onOpen: (_) {},
            onBackground: () {},
            side: layout.iconSize,
            positions: volumePositions([lemon, applications], layout, 128),
            namePlates: plates,
            aliasBadge: (e) => e.isLink,
            env: const {'SILICA_ICONS_DIR': '/nonexistent'},
          ),
        ),
      ),
    );
  }

  testWidgets('the defaults and the alias badge', (tester) async {
    expect(
      (layout.width, layout.height, layout.iconSize, layout.textSize),
      (540.0, 380.0, 128.0, 13.0),
    );
    await pump(tester, plates: false);
    final badge = tester.getRect(find.byKey(const ValueKey('alias badge')));
    // The master: Applications icon at (336, 166), badge 32 at (340, 258): (4, 92) from it.
    expect(badge.size, const Size(32, 32));
    expect(badge.left, 400 - 64 + 4);
    expect(
      badge.top -
          tester
              .getRect(find.byKey(const ValueKey('cell /v/Applications')))
              .top,
      92,
    );
    // Without a custom background: no plate behind the names.
    final name = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('name /v/Lemon.app 0')),
    );
    expect((name.decoration as ShapeDecoration).color, isNull);
  });

  testWidgets('names on plates over a custom background', (tester) async {
    await pump(tester, plates: true);
    final name = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('name /v/Lemon.app 0')),
    );
    expect((name.decoration as ShapeDecoration).color, const Color(0xCCFFFFFF));
    // Kit `Label Plate`: 6 and 2 around the text (the label keeps the icon view's line).
    final plate = tester.getRect(
      find.byKey(const ValueKey('name /v/Lemon.app 0')),
    );
    final text = tester.getRect(find.text('Lemon.app'));
    expect(plate.height, text.height + 2 * namePlatePadY);
  });
}
