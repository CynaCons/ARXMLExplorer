import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';

void main() {
  group('XSD Parser - AUTOSAR-like namespaces', () {
    test('Handles prefixed refs and types by stripping prefix', () {
      const xsd = '''
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:AR="http://autosar.org/schema/r4.0">
        <xs:element name="AR-PACKAGE" type="AR:PkgType"/>
        <xs:complexType name="PkgType">
          <xs:sequence>
            <xs:group ref="AR:PkgChildren"/>
          </xs:sequence>
        </xs:complexType>
        <xs:group name="PkgChildren">
          <xs:sequence>
            <xs:element name="SHORT-NAME"/>
            <xs:element name="ELEMENTS"/>
          </xs:sequence>
        </xs:group>
      </xs:schema>
      ''';

      final parser = XsdParser(xsd);
      final children = parser.getValidChildElements('AR-PACKAGE');

      // Current implementation strips prefixes when resolving @type and @ref
      expect(children, containsAll(<String>['SHORT-NAME', 'ELEMENTS']));
    });
  });
}
