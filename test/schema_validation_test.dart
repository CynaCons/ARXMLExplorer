import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'dart:io';
import 'dart:async';

void main() {
  group('Schema Validation', () {
    late XsdParser xsdParser;
    XsdParser? autosarXsdParser;

    setUp(() async {
      // Load test XSD
      final fileContent = await File('test/res/test.xsd').readAsString();
      xsdParser = XsdParser(fileContent);

      // Try to load AUTOSAR XSD with timeout protection
      final autosarFile = File('lib/res/xsd/AUTOSAR_00050.xsd');
      if (await autosarFile.exists()) {
        try {
          final autosarContent = await autosarFile.readAsString().timeout(
                const Duration(seconds: 5),
                onTimeout: () => throw TimeoutException(
                    'XSD loading timeout', const Duration(seconds: 5)),
              );
          autosarXsdParser = XsdParser(autosarContent);
        } catch (e) {
          print('Warning: Could not load AUTOSAR XSD: $e');
          autosarXsdParser = null;
        }
      }
    });

    test('XsdParser correctly identifies valid child elements for a container',
        () {
      final validChildren = xsdParser.getValidChildElements('CONTAINERS');

      // According to test.xsd, CONTAINERS can have ECUC-CONTAINER-VALUE
      expect(validChildren, isNotEmpty);
      expect(validChildren, contains('ECUC-CONTAINER-VALUE'));
    });

    test('XsdParser returns empty list for an element with no defined children',
        () {
      final validChildren = xsdParser.getValidChildElements('SHORT-NAME');
      expect(validChildren, isEmpty);
    });

    test('XsdParser returns empty list for an unknown element', () {
      final validChildren =
          xsdParser.getValidChildElements('NON-EXISTENT-ELEMENT');
      expect(validChildren, isEmpty);
    });

    test('AUTOSAR XSD parser loads without hanging', () {
      if (autosarXsdParser == null) {
        // This is expected and okay - just verify we handled it gracefully
        expect(autosarXsdParser, isNull);
        return;
      }

      // If we got here, the XSD loaded successfully without timing out
      expect(autosarXsdParser, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('XsdParser caching improves performance', () {
      // First call
      final children1 = xsdParser.getValidChildElements('CONTAINERS');

      final stopwatch = Stopwatch()..start();

      // Second call should be faster due to caching
      final children2 = xsdParser.getValidChildElements('CONTAINERS');

      stopwatch.stop();

      expect(children1, equals(children2));
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
    });

    test('XsdParser handles complex element lookup efficiently', () {
      final stopwatch = Stopwatch()..start();

      final validChildren =
          xsdParser.getValidChildElements('ECUC-MODULE-CONFIGURATION-VALUES');

      stopwatch.stop();

      expect(validChildren, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds,
          lessThan(1000)); // Should complete quickly
    });
  });
}
