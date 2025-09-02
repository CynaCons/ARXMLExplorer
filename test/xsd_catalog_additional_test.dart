import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/features/xsd/state/xsd_catalog.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/core/core.dart';

void main() {
  group('XSD Catalog — additional', () {
    test('Discovers bundled res/xsd entries', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(xsdCatalogProvider.notifier);
      await notifier.initialize();
      final state = container.read(xsdCatalogProvider);
      // Should include some known bundled files
      expect(state.byBasename.containsKey('AUTOSAR_4-3-0.xsd'), true);
      // And version mapping
      expect(
          notifier.findByVersion('4.3.0')?.endsWith('AUTOSAR_4-3-0.xsd'), true);
    });

    test('Add/remove source and rescan updates count', () async {
      final dir = await Directory.systemTemp.createTemp('xsd-src-');
      final a = File('${dir.path}${Platform.pathSeparator}TEST_1-2-3.xsd');
      await a.writeAsString(
          '<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(xsdCatalogProvider.notifier);
      await notifier.initialize();
      final prevCount = container.read(xsdCatalogProvider).count;
      await notifier.addSource(dir.path);
      final nextCount = container.read(xsdCatalogProvider).count;
      expect(nextCount, prevCount + 1);
      await notifier.removeSource(dir.path);
      final afterRemove = container.read(xsdCatalogProvider).count;
      expect(afterRemove, prevCount);
    });

    test('Auto-detect fallback chain chooses bundled when no hints', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tabs = container.read(fileTabsProvider.notifier);
      const xmlContent = '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<AUTOSAR><!-- no schema hints --></AUTOSAR>';
      final path = await tabs.detectSchemaForContent(xmlContent);
      expect(path != null && path!.endsWith('AUTOSAR_00050.xsd'), true);
    });
  });
}
