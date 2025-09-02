import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';

void main() {
  test('XsdParser caching makes repeated lookups fast', () {
    final elements =
        List.generate(60, (i) => '<xs:element name="E$i"/>').join();
    final xsd = '''
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
      <xs:element name="ROOT">
        <xs:complexType>
          <xs:sequence>
            $elements
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    </xs:schema>
    ''';

    final parser = XsdParser(xsd);

    // First call warms caches
    final first = parser.getValidChildElements('ROOT');
    expect(first.length, greaterThanOrEqualTo(50));

    final sw = Stopwatch()..start();
    final second = parser.getValidChildElements('ROOT');
    sw.stop();

    expect(second, equals(first));
    expect(sw.elapsedMilliseconds, lessThan(50));
  });
}
