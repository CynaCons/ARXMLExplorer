import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/arxmlloader.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'package:arxml_explorer/main.dart' show XmlExplorerApp;

void main() {
  group('Debug File Loading', () {
    testWidgets('Test basic provider state changes',
        (WidgetTester tester) async {
      print('🧪 DEBUG TEST: Starting basic provider test');

      // Create simple test XML
      const testXml = '''<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR>
  <AR-PACKAGES>
    <AR-PACKAGE>
      <SHORT-NAME>Test</SHORT-NAME>
    </AR-PACKAGE>
  </AR-PACKAGES>
</AUTOSAR>''';

      // Parse XML
      const loader = ARXMLFileLoader();
      final nodes = loader.parseXmlContent(testXml);
      print('🧪 DEBUG: Parsed ${nodes.length} nodes');

      // Test the provider in isolation
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      Text('Test Widget'),
                      Consumer(
                        builder: (context, ref, child) {
                          final tabs = ref.watch(fileTabsProvider);
                          final loading = ref.watch(loadingStateProvider);
                          return Column(
                            children: [
                              Text('Tabs: ${tabs.length}'),
                              Text('Loading: $loading'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      print('🧪 DEBUG: Initial state rendered');

      // Check initial state
      expect(find.text('Tabs: 0'), findsOneWidget);
      expect(find.text('Loading: false'), findsOneWidget);

      print('🧪 DEBUG: Initial state verified');

      // Now try to add a tab manually
      final notifier = container.read(fileTabsProvider.notifier);

      print('🧪 DEBUG: Setting loading to true');
      container.read(loadingStateProvider.notifier).state = true;
      await tester.pump();

      expect(find.text('Loading: true'), findsOneWidget);
      print('🧪 DEBUG: Loading state updated correctly');

      // Add a tab
      print('🧪 DEBUG: Creating FileTabState');
      final newTab = FileTabState(
        path: 'test.arxml',
        treeStateProvider: arxmlTreeStateProvider(nodes),
        xsdParser: null,
      );

      print('🧪 DEBUG: Adding tab to notifier');
      notifier.state = [newTab];
      container.read(activeTabIndexProvider.notifier).state = 0;

      await tester.pump();

      print('🧪 DEBUG: Checking if tab was added');
      expect(find.text('Tabs: 1'), findsOneWidget);

      print('🧪 DEBUG: Setting loading to false');
      container.read(loadingStateProvider.notifier).state = false;
      await tester.pump();

      expect(find.text('Loading: false'), findsOneWidget);

      print('✅ DEBUG TEST: All basic provider operations work correctly');
    });

    testWidgets('Test TabController behavior with state changes',
        (WidgetTester tester) async {
      print('🧪 DEBUG TEST: Testing TabController behavior');

      // Create test XML
      const testXml = '''<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR><AR-PACKAGES><AR-PACKAGE><SHORT-NAME>Test</SHORT-NAME></AR-PACKAGE></AR-PACKAGES></AUTOSAR>''';

      const loader = ARXMLFileLoader();
      final nodes = loader.parseXmlContent(testXml);

      // Build the actual app
      await tester.pumpWidget(const ProviderScope(child: XmlExplorerApp()));
      await tester.pumpAndSettle();

      print('🧪 DEBUG: App built successfully');

      // Check initial state
      expect(find.text('Open a file to begin'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);

      print('🧪 DEBUG: Initial state verified - no tabs');

      // Get container and notifier
      final container = ProviderScope.containerOf(
          tester.element(find.byType(XmlExplorerApp)));
      final notifier = container.read(fileTabsProvider.notifier);

      print('🧪 DEBUG: Setting loading state');
      container.read(loadingStateProvider.notifier).state = true;
      await tester.pump();

      print('🧪 DEBUG: Adding tab');
      final newTab = FileTabState(
        path: 'test.arxml',
        treeStateProvider: arxmlTreeStateProvider(nodes),
        xsdParser: null,
      );

      notifier.state = [newTab];
      container.read(activeTabIndexProvider.notifier).state = 0;

      print('🧪 DEBUG: Pumping widget to trigger rebuild');
      await tester.pump();

      print('🧪 DEBUG: Checking for TabBar after state change');
      // At this point we should have a TabBar

      // Let's print all widgets to see what's actually rendered
      print('🔍 DEBUG: Widget tree after adding tab:');
      tester.allWidgets
          .where((widget) => widget.runtimeType.toString().contains('Tab'))
          .forEach((widget) {
        print('  - ${widget.runtimeType}: $widget');
      });

      print('🧪 DEBUG: Clearing loading state');
      container.read(loadingStateProvider.notifier).state = false;

      print('🧪 DEBUG: Pumping and settling after clearing loading');
      await tester.pumpAndSettle();

      print('🧪 DEBUG: Final pump and settle complete');

      // Now check if we have tabs
      try {
        expect(find.byType(TabBar), findsOneWidget);
        print('✅ DEBUG: TabBar found successfully');
      } catch (e) {
        print('❌ DEBUG: TabBar not found: $e');
        print('🔍 DEBUG: All widgets in tree:');
        tester.allWidgets.take(20).forEach((widget) {
          print('  - ${widget.runtimeType}');
        });
      }

      print('✅ DEBUG TEST: TabController test completed');
    });
  });
}
