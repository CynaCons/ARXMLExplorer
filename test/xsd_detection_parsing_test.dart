import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/features/xsd/state/xsd_catalog.dart';

void main() {
  group('XSD Detection — header parsing and selection', () {
    late ProviderContainer container;
    setUp(() async {
      container = ProviderContainer();
      // Ensure catalog is initialized so bundled XSDs are available
      await container.read(xsdCatalogProvider.notifier).initialize();
    });
    tearDown(() => container.dispose());

    test('schemaLocation tolerates newlines/tabs/multi-space', () async {
      final tabs = container.read(fileTabsProvider.notifier);
      const xml = '<?xml version="1.0"?>\n'
          '<AUTOSAR xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n'
          '  xsi:schemaLocation="http://autosar.org/schema/r4.0\n\t   AUTOSAR_4-3-0.xsd  \n"\n'
          '>'
          '</AUTOSAR>';
      final path = await tabs.detectSchemaForContent(xml);
      expect(path, isNotNull);
      expect(path!.endsWith('AUTOSAR_4-3-0.xsd'), isTrue);
    });

    test('schemaLocation odd token count gracefully ignores last token',
        () async {
      final tabs = container.read(fileTabsProvider.notifier);
      const xml = '<?xml version="1.0"?>\n'
          '<AUTOSAR xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n'
          '  xsi:schemaLocation="http://autosar.org/schema/r4.0 AUTOSAR_4-3-0.xsd EXTRA_TOKEN"\n'
          '>'
          '</AUTOSAR>';
      final path = await tabs.detectSchemaForContent(xml);
      expect(path, isNotNull);
      expect(path!.endsWith('AUTOSAR_4-3-0.xsd'), isTrue);
    });

    test('noNamespaceSchemaLocation resolves basename', () async {
      final tabs = container.read(fileTabsProvider.notifier);
      const xml = '<?xml version="1.0"?>\n'
          '<AUTOSAR xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n'
          '  noNamespaceSchemaLocation="AUTOSAR_4-3-0.xsd"\n'
          '>'
          '</AUTOSAR>';
      final path = await tabs.detectSchemaForContent(xml);
      expect(path, isNotNull);
      expect(path!.endsWith('AUTOSAR_4-3-0.xsd'), isTrue);
    });

    test('version-only header resolves nearest version from catalog', () async {
      final tabs = container.read(fileTabsProvider.notifier);
      const xml = '<?xml version="1.0"?>\n'
          '<AUTOSAR version="4-3-1">'
          '</AUTOSAR>';
      final path = await tabs.detectSchemaForContent(xml);
      expect(path, isNotNull);
      // Should fall back to 4-3-0 if 4-3-1 not present in bundled catalog
      expect(path!.endsWith('AUTOSAR_4-3-0.xsd'), isTrue);
    });
  });
}
