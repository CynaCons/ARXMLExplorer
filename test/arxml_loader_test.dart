import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/arxmlloader.dart';
import 'package:arxml_explorer/elementnodecontroller.dart';

import 'package:xml/xml.dart';

void main() {
  group('ARXMLFileLoader', () {
    test('parseXmlContent parses a valid XML string', () {
      const arxmlLoader = ARXMLFileLoader();
      final nodeController = ElementNodeController();

      const String dummyXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR>
  <AR-PACKAGE>
    <SHORT-NAME>MyPackage</SHORT-NAME>
    <ELEMENT>
      <SHORT-NAME>MyElement</SHORT-NAME>
    </ELEMENT>
  </AR-PACKAGE>
</AUTOSAR>
''';

      final parsedNodes = arxmlLoader.parseXmlContent(dummyXml, nodeController);

      expect(parsedNodes, isNotEmpty);
      expect(parsedNodes[0].elementText, 'AUTOSAR');
      expect(parsedNodes[0].children, isNotEmpty);
      expect(parsedNodes[0].children[0].elementText, 'AR-PACKAGE');
      expect(parsedNodes[0].children[0].children, isNotEmpty);
      expect(parsedNodes[0].children[0].children[0].elementText, 'SHORT-NAME');
      expect(parsedNodes[0].children[0].children[0].children[0].elementText, 'MyPackage');
    });

    test('parseXmlContent throws XmlParserException for empty XML string', () {
      const arxmlLoader = ARXMLFileLoader();
      final nodeController = ElementNodeController();
      const String emptyXml = '';

      expect(() => arxmlLoader.parseXmlContent(emptyXml, nodeController),
          throwsA(isA<XmlParserException>()));
    });

    test('parseXmlContent throws XmlParserException for XML with no elements', () {
      const arxmlLoader = ARXMLFileLoader();
      final nodeController = ElementNodeController();
      const String noElementsXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!-- Comment only -->
''';

      expect(() => arxmlLoader.parseXmlContent(noElementsXml, nodeController),
          throwsA(isA<XmlParserException>()));
    });
  });
}