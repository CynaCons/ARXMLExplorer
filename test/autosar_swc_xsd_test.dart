import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/xsd_parser.dart';

void main() {
  group('AUTOSAR XSD - SWC Design', () {
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

    test('AR-PACKAGE/ELEMENTS contains key SWC-related entries or value-specs',
        () {
      final kids = autosar.getValidChildElements('ELEMENTS');
      // ELEMENTS is ambiguous; assert presence of either SWC constructs or the value-spec constructs
      final swcSubset = <String>{
        'APPLICATION-SW-COMPONENT-TYPE',
        'CLIENT-SERVER-INTERFACE',
        'SENDER-RECEIVER-INTERFACE',
        'PORT-INTERFACE-MAPPING-SET',
        'SWC-IMPLEMENTATION',
        'SWC-BSW-MAPPING',
      };
      final valueSpecs = <String>{
        'APPLICATION-VALUE-SPECIFICATION',
        'NUMERICAL-VALUE-SPECIFICATION',
        'TEXT-VALUE-SPECIFICATION',
        'RECORD-VALUE-SPECIFICATION',
      };
      expect(
          kids.any(swcSubset.contains) || kids.any(valueSpecs.contains), isTrue,
          reason:
              'ELEMENTS should expose either SWC entries or value-specs depending on context');
    });

    test('APPLICATION-SW-COMPONENT-TYPE exposes INTERNAL-BEHAVIORS wrapper',
        () {
      final kids =
          autosar.getValidChildElements('APPLICATION-SW-COMPONENT-TYPE');
      expect(kids, contains('INTERNAL-BEHAVIORS'));
    });
  });
}
