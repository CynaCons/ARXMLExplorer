import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';

import 'support/open_fixture.dart';

/// The XSD schema is *secondary*. Viewing and navigating ARXML must work with
/// no schema at all — a schema only adds validation badges and add-child
/// suggestions.
///
/// The code already works this way (openNewFile creates the tab and returns;
/// the schema attaches afterwards), but nothing enforced it, so a future change
/// could quietly reintroduce the coupling and block the view on a ~9 MB parse
/// again. These tests make the invariant something CI defends.
void main() {
  group('Editor works without a schema', () {
    testWidgets('tree renders fully with xsdParser == null', (tester) async {
      // autoAttachSchema defaults to false in pumpShell, so the tab genuinely
      // has no schema attached.
      final container = await pumpShell(tester);
      await openFixture(tester, container);

      final tab = container.read(activeTabProvider)!;
      expect(tab.xsdParser, isNull,
          reason: 'precondition: this test is about the no-schema case');

      final tree = container.read(tab.treeStateProvider);
      expect(tree.rootNodes, isNotEmpty);
      expect(tree.visibleNodes, isNotEmpty);
      expect(find.byType(ElementNodeWidget), findsWidgets,
          reason: 'rows must render without a schema');
    });

    testWidgets('expand, collapse and selection work without a schema',
        (tester) async {
      final container = await pumpShell(tester);
      await openFixture(tester, container);

      final tab = container.read(activeTabProvider)!;
      final notifier = container.read(tab.treeStateProvider.notifier);

      final collapsed =
          container.read(tab.treeStateProvider).visibleNodes.length;
      notifier.expandAll();
      await tester.pump();
      final expanded =
          container.read(tab.treeStateProvider).visibleNodes.length;
      expect(expanded, greaterThan(collapsed),
          reason: 'expandAll must work with no schema');

      notifier.collapseAll();
      await tester.pump();
      expect(container.read(tab.treeStateProvider).visibleNodes.length,
          lessThan(expanded));

      notifier.expandAll();
      await tester.pump();
      final target = container.read(tab.treeStateProvider).visibleNodes.last;
      notifier.setSelected(target.id);
      await tester.pump();
      expect(container.read(tab.treeStateProvider).selectedNodeId, target.id);
    });

    testWidgets('editing works without a schema', (tester) async {
      final container = await pumpShell(tester);
      await openFixture(tester, container);

      final tab = container.read(activeTabProvider)!;
      final notifier = container.read(tab.treeStateProvider.notifier);
      final root = container.read(tab.treeStateProvider).rootNodes.first;
      final before = root.children.length;

      // Schema-less add: the schema only *suggests* names, it does not gate
      // the operation.
      notifier.addChildNode(root.id, 'AR-PACKAGES');
      await tester.pump();
      expect(root.children.length, before + 1);

      notifier.undo();
      await tester.pump();
      expect(root.children.length, before);
    });

    testWidgets('opening a file does not wait on schema attachment',
        (tester) async {
      // The tab must exist the moment openNewFile returns. If a future change
      // awaits _attachSchemaForTab inside openNewFile, this fails.
      final container = await pumpShell(tester);
      await openFixture(tester, container);

      expect(container.read(fileTabsProvider), hasLength(1));
      expect(container.read(fileTabsProvider).first.xsdParser, isNull,
          reason: 'the tab is usable before any schema is attached');
    });
  });
}
