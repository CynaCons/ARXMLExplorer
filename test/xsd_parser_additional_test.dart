import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/xsd_parser.dart';

void main() {
  group('XSD Parser - additional coverage', () {
    test('Inline complexType: sequence + group ref + choice', () {
      const xsd = '''
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="ROOT">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="CHILD"/>
              <xs:group ref="GroupA"/>
            </xs:sequence>
            <xs:choice>
              <xs:element name="ALT1"/>
              <xs:element name="ALT2"/>
            </xs:choice>
            <xs:attribute name="ID" type="xs:string"/>
          </xs:complexType>
        </xs:element>

        <xs:group name="GroupA">
          <xs:sequence>
            <xs:element name="G-ITEM1"/>
            <xs:element name="G-ITEM2"/>
          </xs:sequence>
        </xs:group>
      </xs:schema>
      ''';

      final parser = XsdParser(xsd);
      final children = parser.getValidChildElements('ROOT');

      expect(children,
          containsAll(<String>['CHILD', 'G-ITEM1', 'G-ITEM2', 'ALT1', 'ALT2']));
    });

    test('Type-based resolution via @type attribute finds complexType children',
        () {
      const xsd = '''
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="CONTAINER" type="CT:ContainerType" xmlns:CT="http://example.com/ct"/>
        <xs:complexType name="ContainerType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:sequence>
            <xs:element name="ITEM"/>
          </xs:sequence>
        </xs:complexType>
      </xs:schema>
      ''';

      final parser = XsdParser(xsd);
      final children = parser.getValidChildElements('CONTAINER');

      expect(children, contains('ITEM'));
    });

    test('Group recursion guarded by visited set (no infinite loop)', () {
      const xsd = '''
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="ROOT2">
          <xs:complexType>
            <xs:sequence>
              <xs:group ref="GroupA"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>

        <xs:group name="GroupA">
          <xs:sequence>
            <xs:element name="A1"/>
            <xs:group ref="GroupB"/>
          </xs:sequence>
        </xs:group>

        <xs:group name="GroupB">
          <xs:sequence>
            <xs:element name="B1"/>
            <xs:group ref="GroupA"/>
          </xs:sequence>
        </xs:group>
      </xs:schema>
      ''';

      final parser = XsdParser(xsd);
      final children = parser.getValidChildElements('ROOT2');

      // Should include items from both groups exactly once and not hang
      expect(children, containsAll(<String>['A1', 'B1']));
    });
  });
}
