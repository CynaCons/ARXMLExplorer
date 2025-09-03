import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/core.dart';

void main() {
  group('Default collapsed nodes', () {
    test('ADMIN-DATA containers are collapsed by default', () {
      const xml = '''
<AUTOSAR>
  <AR-PACKAGES>
    <AR-PACKAGE>
      <SHORT-NAME>Pkg</SHORT-NAME>
      <ADMIN-DATA>
        <DOC-REVISION>
          <REVISION-LABEL>1.0</REVISION-LABEL>
        </DOC-REVISION>
      </ADMIN-DATA>
    </AR-PACKAGE>
  </AR-PACKAGES>
</AUTOSAR>
''';
      final roots = const ARXMLFileLoader().parseXmlContent(xml);
      // Find ADMIN-DATA node
      bool? isCollapsed;
      void walk(nodes) {
        for (final n in nodes) {
          if (n.elementText == 'ADMIN-DATA') {
            isCollapsed = n.isCollapsed;
            return;
          }
          walk(n.children);
          if (isCollapsed != null) return;
        }
      }

      walk(roots);
      expect(isCollapsed, isTrue, reason: 'ADMIN-DATA should be collapsed by default');
    });
  });
}

