import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/main.dart';

void main() {
  group('File Handling', () {
    /// The default 800x600 test surface is shorter than any real desktop window
    /// and clips the bottom of the NavigationRail. Give tests room.
    Future<void> useDesktopSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    testWidgets('Create New File action is reachable via the overflow menu',
        (WidgetTester tester) async {
      await useDesktopSurface(tester);
      await tester.pumpWidget(const XmlExplorerApp());

      // New File moved off the rail into the overflow menu when the rail was
      // decluttered. Open the menu and assert the entry is there and enabled.
      await tester.tap(find.byKey(const Key('action-more')));
      await tester.pumpAndSettle();

      final item = find.byKey(const Key('action-new-file'));
      expect(item, findsOneWidget);
      // Deliberately does not select it: createNewFile() opens a platform save
      // dialog via file_picker, which throws MissingPluginException in a widget
      // test (it did so on Linux CI). The dialog is not ours to test.
      expect(
        tester.widget<PopupMenuItem<dynamic>>(item).enabled,
        isTrue,
      );
    });

    testWidgets('App initializes correctly', (WidgetTester tester) async {
      await useDesktopSurface(tester);
      await tester.pumpWidget(const XmlExplorerApp());

      // Verify the primary rail actions are present.
      expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
      expect(find.byKey(const Key('action-save')), findsOneWidget);
      expect(find.byKey(const Key('action-more')), findsOneWidget);
    });

    // Test the ARXML loader directly without file picker dependency
    test('ARXMLFileLoader can load file with provided path', () async {
      const arxmlLoader = ARXMLFileLoader();

      // Test with test file path
      final result = await arxmlLoader.openFile('test/res/generic_ecu.arxml');

      expect(result, isNotEmpty);
      expect(result[0].elementText, 'AUTOSAR');
    });
  });
}
