import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';
import 'package:arxml_explorer/core/core.dart';

void main() {
  test('Validator reports invalid child under parent based on schema',
      () async {
    final xsd = await File('test/res/test.xsd').readAsString();
    final parser = XsdParser(xsd, verbose: false);

    const arxml = '''
<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR>
  <AR-PACKAGES>
    <AR-PACKAGE>
      <SHORT-NAME>Pkg</SHORT-NAME>
      <ELEMENTS>
        <ECUC-MODULE-CONFIGURATION-VALUES>
          <SHORT-NAME>Cfg</SHORT-NAME>
          <CONTAINERS>
            <ECUC-CONTAINER-VALUE>
              <SHORT-NAME>Inner</SHORT-NAME>
              <DEFINITION-REF>Some.Def</DEFINITION-REF>
              <INVALID-CHILD />
            </ECUC-CONTAINER-VALUE>
          </CONTAINERS>
        </ECUC-MODULE-CONFIGURATION-VALUES>
      </ELEMENTS>
    </AR-PACKAGE>
  </AR-PACKAGES>
</AUTOSAR>
''';

    final nodes = const ARXMLFileLoader().parseXmlContent(arxml);
    final issues = const ArxmlValidator().validate(nodes, parser);
    expect(issues.any((i) => i.path.contains('INVALID-CHILD')), isTrue);
  });
}
