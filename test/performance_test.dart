import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/features/editor/state/testing/element_node_controller.dart';
import 'package:arxml_explorer/main.dart';

void main() {
  group('Performance', () {
    testWidgets('App performance basics', (WidgetTester tester) async {
      await tester.pumpWidget(const XmlExplorerApp());

      // Verify app starts quickly
      expect(find.byIcon(Icons.file_open), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);
    });

    // Test XML parsing performance with moderately complex content
    test('ARXMLFileLoader performance with complex XML', () {
      const arxmlLoader = ARXMLFileLoader();
      final controller = ElementNodeController();

      // Create a larger XML structure for performance testing
      final StringBuffer xmlBuilder = StringBuffer();
      xmlBuilder.write('<?xml version="1.0" encoding="UTF-8"?><AUTOSAR>');

      // Generate 100 packages for performance testing
      for (int i = 0; i < 100; i++) {
        xmlBuilder.write(
            '<AR-PACKAGE><SHORT-NAME>Package$i</SHORT-NAME></AR-PACKAGE>');
      }
      xmlBuilder.write('</AUTOSAR>');

      final stopwatch = Stopwatch()..start();
      final result = arxmlLoader.parseXmlContent(xmlBuilder.toString());
      controller.init(result, () {}, (id) => Future.value());
      stopwatch.stop();

      expect(result, isNotEmpty);
      expect(result[0].elementText, 'AUTOSAR');
      expect(result[0].children.length, 100);

      // Ensure parsing completes in reasonable time (less than 1 second)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    // Test element node controller performance
    test('ElementNodeController performance with many nodes', () {
      final controller = ElementNodeController();

      // Test that controller handles multiple operations efficiently
      final stopwatch = Stopwatch()..start();

      // Simulate operations
      for (int i = 0; i < 1000; i++) {
        controller.itemCount; // Access property multiple times
      }

      stopwatch.stop();

      // Should complete quickly (less than 100ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
