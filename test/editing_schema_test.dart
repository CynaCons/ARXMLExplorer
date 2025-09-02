import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/features/editor/state/testing/element_node_controller.dart';
import 'package:arxml_explorer/main.dart';

void main() {
  group('Editing and Schema', () {
    testWidgets('App contains editing elements', (WidgetTester tester) async {
      await tester.pumpWidget(const XmlExplorerApp());

      // Verify the main UI elements are present for editing
      expect(find.byIcon(Icons.file_open), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);
    });

    // Test XML parsing and node editing capabilities
    test('ARXMLFileLoader parseXmlContent handles complex XML', () {
      const arxmlLoader = ARXMLFileLoader();
      final controller = ElementNodeController();

      const String complexXml = '''<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR>
  <AR-PACKAGE>
    <SHORT-NAME>MyPackage</SHORT-NAME>
    <ELEMENTS>
      <ECUC-MODULE-CONFIGURATION-VALUES>
        <SHORT-NAME>Os</SHORT-NAME>
        <CONTAINERS>
          <ECUC-CONTAINER-VALUE>
            <SHORT-NAME>OsTask</SHORT-NAME>
            <DEFINITION-REF>/GenericModule/Os/OsTask</DEFINITION-REF>
          </ECUC-CONTAINER-VALUE>
        </CONTAINERS>
      </ECUC-MODULE-CONFIGURATION-VALUES>
    </ELEMENTS>
  </AR-PACKAGE>
</AUTOSAR>''';

      final result = arxmlLoader.parseXmlContent(complexXml);
      controller.init(result, () {}, (id) => Future.value());

      expect(result, isNotEmpty);
      expect(result[0].elementText, 'AUTOSAR');
      expect(result[0].children, isNotEmpty);
    });

    // Test element node controller functionality
    test('ElementNodeController can manage nodes', () {
      final controller = ElementNodeController();

      // Test that controller initializes correctly
      expect(controller.itemCount, 0);
      expect(controller.flatMapValues, isEmpty);
    });
  });
}
