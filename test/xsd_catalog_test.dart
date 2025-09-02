import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/features/xsd/state/xsd_catalog.dart';

void main() {
  test('XSD catalog discovers from sources and resolves by version/basename',
      () async {
    final temp = await Directory.systemTemp.createTemp('xsd_cat_');
    try {
      final d = Directory('${temp.path}${Platform.pathSeparator}schemas');
      await d.create(recursive: true);
      final a = File('${d.path}${Platform.pathSeparator}AUTOSAR_4-3-0.xsd');
      final b = File('${d.path}${Platform.pathSeparator}OTHER_1.2.3.xsd');
      await a.writeAsString(
          '<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>');
      await b.writeAsString(
          '<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>');

      final n = XsdCatalogNotifier();
      await n.addSource(d.path);
      final st = n.state;
      expect(st.count, 2);
      expect(n.findByVersion('4.3.0')?.endsWith('AUTOSAR_4-3-0.xsd'), true);
      expect(n.findByBasename('OTHER_1.2.3.xsd')?.endsWith('OTHER_1.2.3.xsd'),
          true);
    } finally {
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  });
}
