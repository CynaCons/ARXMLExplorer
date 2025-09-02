import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';

void main() {
  group('AUTOSAR XSD - BSW Configuration (ECUC)', () {
    late XsdParser autosar;

    setUpAll(() async {
      final f = File('lib/res/xsd/AUTOSAR_4-1-1.xsd');
      expect(await f.exists(), isTrue,
          reason: 'Expected AUTOSAR_4-1-1.xsd to exist in lib/res/xsd');
      final content = await f.readAsString();
      autosar = XsdParser(
        content,
        verbose: false,
        particleDepthLimit: 5,
        groupDepthLimit: 4,
      );
    });

    test('ECUC-MODULE-CONFIGURATION-VALUES has CONTAINERS wrapper', () {
      final kids =
          autosar.getValidChildElements('ECUC-MODULE-CONFIGURATION-VALUES');
      expect(kids, contains('CONTAINERS'));
    });

    test('ECUC-CONTAINER-VALUE exposes wrapper children and nested containers',
        () {
      final kids = autosar.getValidChildElements('ECUC-CONTAINER-VALUE');
      expect(
        kids,
        containsAll(<String>[
          'PARAMETER-VALUES',
          'REFERENCE-VALUES',
          'SUB-CONTAINERS', // wrapper for nested container values
        ]),
      );
    });
  });
}
