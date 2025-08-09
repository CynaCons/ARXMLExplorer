import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/main.dart';
import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/arxmlloader.dart';
import 'dart:io';

void main() {
  group('UI/UX Features', () {
    testWidgets('Loading indicator is displayed during file operations',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      final notifier = container.read(fileTabsProvider.notifier);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [fileTabsProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(home: MyHomePage(title: 'Test')),
        ),
      );

      // Manually set loading state to true
      notifier.isLoading = true;
      notifier.state = List.of(notifier.state); // Trigger rebuild
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Manually set loading state to false
      notifier.isLoading = false;
      notifier.state = List.of(notifier.state); // Trigger rebuild
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Collapse/Expand All buttons work', (WidgetTester tester) async {
      final container = ProviderContainer();
      final notifier = container.read(fileTabsProvider.notifier);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [fileTabsProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(home: MyHomePage(title: 'Test')),
        ),
      );

      // Open a file
      final fileContent =
          await File('test/res/complex_nested.arxml').readAsString();
      final nodes = const ARXMLFileLoader().parseXmlContent(fileContent);
      final newTab = FileTabState(
        path: 'test.arxml',
        treeStateProvider: arxmlTreeStateProvider(nodes),
      );
      notifier.state = [newTab];
      await tester.pumpAndSettle();

      // Verify initial state has many nodes
      final treeNotifier = container.read(newTab.treeStateProvider.notifier);
      final initialVisibleCount = treeNotifier.state.visibleNodes.length;
      expect(initialVisibleCount, greaterThan(treeNotifier.state.rootNodes.length));

      // Tap Collapse All
      await tester.tap(find.byIcon(Icons.unfold_less));
      await tester.pumpAndSettle();
      
      // Re-read the notifier state after UI interaction
      final collapsedState = container.read(newTab.treeStateProvider);
      expect(collapsedState.visibleNodes.length, collapsedState.rootNodes.length);

      // Tap Expand All
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();

      final expandedState = container.read(newTab.treeStateProvider);
      expect(expandedState.visibleNodes.length, initialVisibleCount);
    });
  });
}
