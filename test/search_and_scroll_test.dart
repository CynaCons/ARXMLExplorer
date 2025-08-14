import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/arxmlloader.dart';

import 'package:arxml_explorer/elementnodecontroller.dart';
import 'package:arxml_explorer/main.dart' show XmlExplorerApp;

void main() {
  group('Search and Scroll', () {
    late ElementNodeController nodeController;
    late ARXMLFileLoader arxmlLoader;

    setUp(() {
      nodeController = ElementNodeController();
      arxmlLoader = const ARXMLFileLoader();
      const xmlContent = '''
<AUTOSAR>
  <AR-PACKAGES>
    <AR-PACKAGE>
      <SHORT-NAME>MyECU</SHORT-NAME>
      <ELEMENTS>
        <ECUC-MODULE-CONFIGURATION-VALUES>
          <SHORT-NAME>Os</SHORT-NAME>
          <CONTAINERS>
            <ECUC-CONTAINER-VALUE>
              <SHORT-NAME>OsTask</SHORT-NAME>
              <DEFINITION-REF>/MICROSAR/Os/OsTask</DEFINITION-REF>
              <PARAMETER-VALUES>
                <ECUC-NUMERICAL-PARAM-VALUE>
                  <SHORT-NAME>OsTaskActivation</SHORT-NAME>
                  <VALUE>1</VALUE>
                </ECUC-NUMERICAL-PARAM-VALUE>
              </PARAMETER-VALUES>
            </ECUC-CONTAINER-VALUE>
            <ECUC-CONTAINER-VALUE>
              <SHORT-NAME>OsEvent</SHORT-NAME>
              <DEFINITION-REF>/MICROSAR/Os/OsEvent</DEFINITION-REF>
              <PARAMETER-VALUES>
                <ECUC-TEXTUAL-PARAM-VALUE>
                  <SHORT-NAME>OsEventMask</SHORT-NAME>
                  <VALUE>AUTO</VALUE>
                </ECUC-TEXTUAL-PARAM-VALUE>
              </PARAMETER-VALUES>
            </ECUC-CONTAINER-VALUE>
            <ECUC-CONTAINER-VALUE>
              <SHORT-NAME>OsCounter</SHORT-NAME>
              <DEFINITION-REF>/MICROSAR/Os/OsCounter</DEFINITION-REF>
              <SUB-CONTAINERS>
                <ECUC-CONTAINER-VALUE>
                  <SHORT-NAME>OsCounterSpecific</SHORT-NAME>
                  <DEFINITION-REF>/MICROSAR/Os/OsCounterSpecific</DEFINITION-REF>
                  <PARAMETER-VALUES>
                    <ECUC-NUMERICAL-PARAM-VALUE>
                      <SHORT-NAME>OsCounterValue</SHORT-NAME>
                      <VALUE>42</VALUE>
                    </ECUC-NUMERICAL-PARAM-VALUE>
                  </PARAMETER-VALUES>
                </ECUC-CONTAINER-VALUE>
              </SUB-CONTAINERS>
            </ECUC-CONTAINER-VALUE>
          </CONTAINERS>
        </ECUC-MODULE-CONFIGURATION-VALUES>
      </ELEMENTS>
    </AR-PACKAGE>
  </AR-PACKAGES>
</AUTOSAR>
''';
      final nodes = arxmlLoader.parseXmlContent(xmlContent);
      nodeController.init(nodes, () {}, (id) => Future.value());
    });

    testWidgets(
        'Search for a deeply nested node, tap suggestion, and verify scroll',
        (WidgetTester tester) async {
      await tester.pumpWidget(const XmlExplorerApp());

      // Open a file
      await tester.tap(find.byIcon(Icons.file_open));
      await tester.pumpAndSettle();

      // Simulate search and tap
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'OsCounterValue');
      await tester.pumpAndSettle();
      await tester.tap(find.text('OsCounterValue').last);
      await tester.pumpAndSettle();

      // Verify the node is now visible and scrolled to
      expect(find.textContaining('OsCounterValue'), findsOneWidget);
    });
  });
}
