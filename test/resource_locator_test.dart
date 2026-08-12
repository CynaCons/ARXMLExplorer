import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:arxml_explorer/core/resources/resource_locator.dart';

/// v0.4.2 — schema paths used to be bare `lib/res/xsd/...` strings resolved
/// against the process working directory, so an installed build found nothing.
void main() {
  group('ResourceLocator', () {
    setUp(ResourceLocator.resetCache);
    tearDown(ResourceLocator.resetCache);

    test('search paths include the checkout and executable-relative locations',
        () {
      final paths = const ResourceLocator().xsdSearchPaths();

      expect(paths, isNotEmpty);
      expect(
        paths.any((path) => p.split(path).contains('flutter_assets')),
        isTrue,
        reason: 'an installed build ships schemas in the asset bundle',
      );
      expect(
        paths.any((path) => p.isAbsolute(path)),
        isTrue,
        reason: 'resolution must not depend solely on the working directory',
      );
    });

    test('search paths are normalised and free of duplicates', () {
      final paths = const ResourceLocator().xsdSearchPaths();
      expect(paths.toSet().length, paths.length);
      for (final path in paths) {
        expect(path, p.normalize(path));
      }
    });

    test('resolves a schema from the checkout directory', () {
      final dir = Directory(ResourceLocator.bundledXsdRelative);
      if (!dir.existsSync()) {
        markTestSkipped('AUTOSAR XSDs not provisioned; see README');
        return;
      }
      final resolved = const ResourceLocator().resolveXsd('AUTOSAR_00050.xsd');
      expect(resolved, isNotNull);
      expect(File(resolved!).existsSync(), isTrue);
    });

    test('resolveXsd tolerates a full path and matches on basename', () {
      final dir = Directory(ResourceLocator.bundledXsdRelative);
      if (!dir.existsSync()) {
        markTestSkipped('AUTOSAR XSDs not provisioned; see README');
        return;
      }
      const locator = ResourceLocator();
      final direct = locator.resolveXsd('AUTOSAR_00050.xsd');
      final viaPath =
          locator.resolveXsd('http/autosar.org/schema/AUTOSAR_00050.xsd');
      expect(viaPath, direct);
    });

    test('resolveXsd returns null for an unknown schema', () {
      expect(const ResourceLocator().resolveXsd('DEFINITELY_NOT_HERE.xsd'),
          isNull);
    });

    test('isBundledPath recognises schemas under a search path', () {
      final dir = Directory(ResourceLocator.bundledXsdRelative);
      if (!dir.existsSync()) {
        markTestSkipped('AUTOSAR XSDs not provisioned; see README');
        return;
      }
      const locator = ResourceLocator();
      final resolved = locator.resolveXsd('AUTOSAR_00050.xsd')!;

      expect(locator.isBundledPath(resolved), isTrue);
      expect(
        locator.isBundledPath(p.join(Directory.systemTemp.path, 'other.xsd')),
        isFalse,
      );
    });

    test('isBundledPath is separator-agnostic', () {
      final dir = Directory(ResourceLocator.bundledXsdRelative);
      if (!dir.existsSync()) {
        markTestSkipped('AUTOSAR XSDs not provisioned; see README');
        return;
      }
      const locator = ResourceLocator();
      final resolved = locator.resolveXsd('AUTOSAR_00050.xsd')!;

      // The old implementation matched the literal substring '/lib/res/xsd/',
      // so a Windows-separated path reported false.
      expect(locator.isBundledPath(resolved.replaceAll('/', r'\')), isTrue);
      expect(locator.isBundledPath(resolved.replaceAll(r'\', '/')), isTrue);
    });
  });
}
