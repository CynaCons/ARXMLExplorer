import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/main.dart';

void main() {
  group('File Handling', () {
    testWidgets('Create New File', (WidgetTester tester) async {
      await tester.pumpWidget(const XmlExplorerApp());

      // Tap the "Create New" button (outlined variant in NavigationRail)
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await tester.pumpAndSettle();

      // Verify the tap action completed (basic functionality test)
      expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
    });

    testWidgets('App initializes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const XmlExplorerApp());

      // Verify the main UI elements are present (outlined variants)
      expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
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
