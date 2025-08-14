import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_core/arxml_core.dart' show RefNormalizer;

void main() {
  group('RefNormalizer.normalize', () {
    test('keeps absolute path and collapses slashes', () {
      expect(RefNormalizer.normalize('/Pkg//Comp/Port'), '/Pkg/Comp/Port');
    });

    test('converts backslashes and vendor separators to /', () {
      expect(RefNormalizer.normalize('Pkg\\Comp::Port', basePath: '/Root'),
          '/Root/Pkg/Comp/Port');
    });

    test('resolves dot segments with base', () {
      expect(RefNormalizer.normalize('../Other/Port', basePath: '/Pkg/Comp'),
          '/Pkg/Other/Port');
      expect(RefNormalizer.normalize('./Here', basePath: '/Pkg/Comp'),
          '/Pkg/Comp/Here');
    });

    test('trims quotes and whitespace', () {
      expect(RefNormalizer.normalize('  "/Pkg/Comp"  '), '/Pkg/Comp');
    });

    test('namespace stripping optional', () {
      expect(
          RefNormalizer.normalize('/AR:Pkg/AR:Comp',
              stripNamespacePrefixes: true),
          '/Pkg/Comp');
      expect(
          RefNormalizer.normalize('/AR:Pkg/AR:Comp',
              stripNamespacePrefixes: false),
          '/AR:Pkg/AR:Comp');
    });

    test('relative without base becomes absolute from root of given segments',
        () {
      expect(RefNormalizer.normalize('A/B/C'), '/A/B/C');
    });
  });
}
