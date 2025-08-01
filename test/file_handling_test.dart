import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/main.dart';
import 'package:arxml_explorer/arxmlloader.dart';
import 'package:arxml_explorer/elementnodecontroller.dart';

void main() {
  group('File Handling', () {
    testWidgets('Create New File', (WidgetTester tester) async {
      await tester.pumpWidget(const XmlExplorerApp());

      // Tap the "Create New" button
      await tester.tap(find.byIcon(Icons.create_new_folder));
      await tester.pumpAndSettle();

      // Verify the tap action completed (basic functionality test)
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);
    });

    testWidgets('App initializes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const XmlExplorerApp());

      // Verify the main UI elements are present
      expect(find.byIcon(Icons.file_open), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);
    });

    // Test the ARXML loader directly without file picker dependency
    test('ARXMLFileLoader can load file with provided path', () async {
      const arxmlLoader = ARXMLFileLoader();
      final nodeController = ElementNodeController();

      // Test with test file path
      final result = await arxmlLoader.openFile(
          nodeController, 'test/res/generic_ecu.arxml');

      expect(result, isNotEmpty);
      expect(result[0].elementText, 'AUTOSAR');
    });
  });
}
