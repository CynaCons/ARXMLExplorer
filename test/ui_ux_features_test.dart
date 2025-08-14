import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/ui/home_shell.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'package:arxml_explorer/arxmlloader.dart';
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
      final container = ProviderContainer();
      final notifier = container.read(fileTabsProvider.notifier);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [fileTabsProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(home: HomeShell()),
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
      // Replace pumpAndSettle with bounded pumps to prevent long waits
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // Verify initial state has many nodes
      final treeNotifier = container.read(newTab.treeStateProvider.notifier);
      final initialVisibleCount = treeNotifier.state.visibleNodes.length;
      expect(initialVisibleCount,
          greaterThan(treeNotifier.state.rootNodes.length));

      // Tap Collapse All
      await tester.tap(find.byIcon(Icons.unfold_less));
      await tester.pump(const Duration(milliseconds: 50));

      // Re-read the notifier state after UI interaction
      final collapsedState = container.read(newTab.treeStateProvider);
      expect(
          collapsedState.visibleNodes.length, collapsedState.rootNodes.length);

      // Tap Expand All
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pump(const Duration(milliseconds: 50));

      final expandedState = container.read(newTab.treeStateProvider);
      expect(expandedState.visibleNodes.length, initialVisibleCount);
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
