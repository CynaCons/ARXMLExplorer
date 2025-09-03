import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/ui/home_shell.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'dart:io';

void main() {
  group('UI/UX Features', () {
    testWidgets('Loading indicator is displayed during file operations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomeShell()),
        ),
      );

      // Toggle loading state via provider
      final ctx = tester.element(find.byType(HomeShell));
      final container = ProviderScope.containerOf(ctx);

      container.read(loadingStateProvider.notifier).state = true;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      container.read(loadingStateProvider.notifier).state = false;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Collapse/Expand All buttons work',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileTabsProvider.overrideWith((ref) => FileTabsNotifier(ref))
          ],
          child: const MaterialApp(home: HomeShell()),
        ),
      );

      // Access app container
      final ctx = tester.element(find.byType(HomeShell));
      final appContainer = ProviderScope.containerOf(ctx);
      final tabsNotifier = appContainer.read(fileTabsProvider.notifier);

      // Create a tab with parsed nodes (sync read to avoid async deadlocks in testWidgets)
      final fileContent =
          File('test/res/complex_nested.arxml').readAsStringSync();
      final nodes = const ARXMLFileLoader().parseXmlContent(fileContent);
      final newTab = FileTabState(
        path: 'test.arxml',
        treeStateProvider: arxmlTreeStateProvider(nodes),
      );
      tabsNotifier.state = [newTab];
      await tester.pump(const Duration(milliseconds: 50));

      // Work with the tree state within the same container as the app
      final treeNotifier = appContainer.read(newTab.treeStateProvider.notifier);
      final initialVisibleCount = treeNotifier.state.visibleNodes.length;
      expect(initialVisibleCount,
          greaterThan(treeNotifier.state.rootNodes.length));

      // Collapse all
      treeNotifier.collapseAll();
      await tester.pump(const Duration(milliseconds: 50));
      final collapsedState = appContainer.read(newTab.treeStateProvider);
      expect(
          collapsedState.visibleNodes.length, collapsedState.rootNodes.length);

      // Expand all
      treeNotifier.expandAll();
      await tester.pump(const Duration(milliseconds: 50));
      final expandedState = appContainer.read(newTab.treeStateProvider);
      // With default-collapsed containers (e.g., ADMIN-DATA), expandAll may reveal
      // more nodes than initially visible; accept >= initial count.
      expect(expandedState.visibleNodes.length,
          greaterThanOrEqualTo(initialVisibleCount));
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
