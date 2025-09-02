import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';

void main() {
  group('AUTOSAR XSD children (real schema)', () {
    late XsdParser autosar;

    setUpAll(() async {
      final f = File('lib/res/xsd/AUTOSAR_00050.xsd');
      final content = await f.readAsString();
      autosar = XsdParser(content,
          verbose: false, particleDepthLimit: 4, groupDepthLimit: 3);
    });

    test('AUTOSAR root exposes top-level children', () {
      final kids = autosar.getValidChildElements('AUTOSAR');
      expect(
          kids,
          containsAll(<String>[
            'FILE-INFO-COMMENT',
            'ADMIN-DATA',
            'INTRODUCTION',
            'AR-PACKAGES'
          ]));
    });

    test('AR-PACKAGES allows AR-PACKAGE as child', () {
      final kids = autosar.getValidChildElements('AR-PACKAGES');
      expect(kids, contains('AR-PACKAGE'));
    });

    test('AR-PACKAGE exposes ELEMENTS and REFERENCE-BASES', () {
      final kids = autosar.getValidChildElements('AR-PACKAGE');
      expect(kids, containsAll(<String>['ELEMENTS', 'REFERENCE-BASES']));
    });

    test(
        'AR-PACKAGE/ELEMENTS includes known elements (e.g., APPLICATION-INTERFACE)',
        () {
      // Note: getValidChildElements() currently lacks parent context for disambiguating identically named elements.
      // This test documents the intended behavior and may fail until the parser supports scoped lookup.
      final kids = autosar.getValidChildElements('ELEMENTS');
      expect(kids, contains('APPLICATION-INTERFACE'));
    }, skip: true); // TODO: re-enable when contextual lookup is implemented
  });
}
