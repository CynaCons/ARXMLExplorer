import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';

import 'support/open_fixture.dart';

/// v0.4.1 — Save / Save All / Undo / Redo were implemented on the providers but
/// unreachable from the UI after the AppBar was removed. These tests pin the
/// toolbar wiring so the actions cannot silently disappear again.
void main() {
  group('Editor toolbar actions', () {
    late Directory tmp;
    late String fixture;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('arxml_actions_test');
      fixture = '${tmp.path}${Platform.pathSeparator}sample.arxml';
      await File(fixture)
          .writeAsString(await File(kGenericEcuFixture).readAsString());
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    testWidgets('Save, Save All, Undo and Redo are present in the rail',
        (tester) async {
      await pumpShell(tester);

      // Primary actions stay on the rail...
      expect(find.byKey(const Key('action-open-file')), findsOneWidget);
      expect(find.byKey(const Key('action-save')), findsOneWidget);
      expect(find.byKey(const Key('action-undo')), findsOneWidget);
      expect(find.byKey(const Key('action-redo')), findsOneWidget);

      // ...secondary ones moved into the overflow menu.
      expect(find.byKey(const Key('action-save-all')), findsNothing);
      await tester.tap(find.byKey(const Key('action-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action-save-all')), findsOneWidget);
      expect(find.byKey(const Key('action-search')), findsOneWidget);
    });

    testWidgets('Undo and Redo are disabled until an edit is made',
        (tester) async {
      final container = await pumpShell(tester);
      await openFixture(tester, container, path: fixture);

      IconButton buttonFor(String key) =>
          tester.widget<IconButton>(find.byKey(Key(key)));

      expect(buttonFor('action-undo').onPressed, isNull,
          reason: 'nothing to undo on a freshly opened file');
      expect(buttonFor('action-redo').onPressed, isNull);

      // Make a structural edit through the tree notifier.
      final tab = container.read(activeTabProvider)!;
      final notifier = container.read(tab.treeStateProvider.notifier);
      final rootId = container.read(tab.treeStateProvider).rootNodes.first.id;
      notifier.addChildNode(rootId, 'AR-PACKAGES');
      await tester.pump();

      expect(buttonFor('action-undo').onPressed, isNotNull,
          reason: 'an applied command should enable Undo');
      expect(buttonFor('action-redo').onPressed, isNull);
    });

    testWidgets('Undo reverts an edit and Redo reapplies it', (tester) async {
      final container = await pumpShell(tester);
      await openFixture(tester, container, path: fixture);

      final tab = container.read(activeTabProvider)!;
      final notifier = container.read(tab.treeStateProvider.notifier);
      final root = container.read(tab.treeStateProvider).rootNodes.first;
      final before = root.children.length;

      notifier.addChildNode(root.id, 'AR-PACKAGES');
      await tester.pump();
      expect(root.children.length, before + 1);

      await tester.tap(find.byKey(const Key('action-undo')));
      await tester.pump();
      expect(root.children.length, before,
          reason: 'Undo should revert the add');
      expect(container.read(tab.treeStateProvider).canRedo, isTrue);

      await tester.tap(find.byKey(const Key('action-redo')));
      await tester.pump();
      expect(root.children.length, before + 1,
          reason: 'Redo should reapply the add');
    });

    testWidgets('Save writes the tree back and clears the dirty flag',
        (tester) async {
      final container = await pumpShell(tester);
      await openFixture(tester, container, path: fixture);

      final tab = container.read(activeTabProvider)!;
      final notifier = container.read(tab.treeStateProvider.notifier);
      final root = container.read(tab.treeStateProvider).rootNodes.first;
      notifier.addChildNode(root.id, 'AR-PACKAGES');
      container
          .read(fileTabsProvider.notifier)
          .markDirtyForTreeProvider(tab.treeStateProvider);
      await tester.pump();
      expect(container.read(fileTabsProvider).first.isDirty, isTrue);

      // Save and the read-back both touch the real filesystem, so both need a
      // real event loop — `testWidgets` bodies run under fake async, where
      // dart:io futures never complete.
      late final String written;
      await tester.runAsync(() async {
        await container.read(fileTabsProvider.notifier).saveActiveFile();
        written = await File(fixture).readAsString();
      });
      await tester.pump();

      expect(container.read(fileTabsProvider).first.isDirty, isFalse,
          reason: 'Save should clear the dirty indicator');
      expect(written, contains('AR-PACKAGES'));
    });
  });
}
