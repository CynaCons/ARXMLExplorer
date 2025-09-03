import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/main.dart' as app show XmlExplorerApp;
import 'package:arxml_explorer/core/models/element_node.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';

void main() {
  group('File Loading Integration Tests', () {
    testWidgets('App loads and shows initial state correctly',
        (WidgetTester tester) async {
      print('🧪 TEST START: App loads and shows initial state correctly');

      // Build the app
      print('🏗️ Building app widget...');
      await tester.pumpWidget(const ProviderScope(child: app.XmlExplorerApp()));
      // Prefer bounded pumps over unbounded settle
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      print('⏳ Waiting for app to settle...');
      await tester.pumpAndSettle();
      print('✅ App built and settled');

      // Verify initial state
      print('🔍 Verifying initial state...');
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Open a file to begin'), findsOneWidget);
      expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);

      print('✅ Initial app state verified - TEST PASSED');
    }, timeout: const Timeout(Duration(seconds: 45)));

    testWidgets('File loading simulation works end-to-end',
        (WidgetTester tester) async {
      print('🧪 TEST START: File loading simulation works end-to-end');

      // Create test XML content
      print('📄 Creating test XML content...');
      const testXmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR xmlns="http://autosar.org/schema/r4.0">
  <AR-PACKAGES>
    <AR-PACKAGE>
      <SHORT-NAME>TestPackage</SHORT-NAME>
      <ELEMENTS>
        <APPLICATION-SW-COMPONENT-TYPE>
          <SHORT-NAME>TestComponent</SHORT-NAME>
          <PORTS>
            <P-PORT-PROTOTYPE>
              <SHORT-NAME>TestPort</SHORT-NAME>
            </P-PORT-PROTOTYPE>
          </PORTS>
        </APPLICATION-SW-COMPONENT-TYPE>
      </ELEMENTS>
    </AR-PACKAGE>
  </AR-PACKAGES>
</AUTOSAR>''';

      // Parse the XML to create nodes
      print('🔄 Parsing XML content...');
      const arxmlLoader = ARXMLFileLoader();
      final nodes = arxmlLoader.parseXmlContent(testXmlContent);

      print('📄 Test XML parsed, ${nodes.length} root nodes created');

      // Verify the parsing worked
      expect(nodes.length, 1);
      expect(nodes.first.elementText, contains('AUTOSAR'));
      print('✅ XML parsing verification passed');

      // Build the app with a custom provider scope to inject test data
      print('🏗️ Building app with test data providers...');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override the file tabs provider with test data
            fileTabsProvider.overrideWith((ref) {
              print('🔧 Creating TestFileTabsNotifier...');
              return TestFileTabsNotifier(ref, nodes);
            }),
          ],
          child: const app.XmlExplorerApp(),
        ),
      );
      // Bounded pumps instead of pumpAndSettle
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      print('🚀 App built with test data');

      // Verify initial state
      print('🔍 Verifying initial state...');
      expect(find.byType(NavigationRail), findsOneWidget);

      // Trigger file loading by calling the test notifier
      print('🔍 Getting provider container...');
      final container = ProviderScope.containerOf(
          tester.element(find.byType(app.XmlExplorerApp)));
      print('🔍 Getting test notifier...');
      final notifier =
          container.read(fileTabsProvider.notifier) as TestFileTabsNotifier;

      // Simulate file loading
      print('📁 Simulating file load...');
      await notifier.simulateFileLoad();
      print('⏳ Waiting for UI to settle after file load...');
      // Pump a few frames to allow UI to rebuild
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      // Avoid potential infinite settle loops; pump a few frames instead
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      print('📁 File loading simulated');

      // Verify that the file was loaded and UI is displayed
      print('🔍 Looking for TabBar...');
      expect(find.byType(TabBar), findsOneWidget);
      print('🔍 Looking for TabBarView...');
      expect(find.byType(TabBarView), findsOneWidget);

      print('🔍 Looking for element widgets...');
      expect(find.byType(ElementNodeWidget), findsAtLeastNWidgets(1));

      print('🔍 Looking for AUTOSAR text...');
      expect(find.textContaining('AUTOSAR'), findsAtLeastNWidgets(1));

      print(
          '✅ File loading integration test completed successfully - TEST PASSED');
    }, timeout: const Timeout(Duration(seconds: 45)));

    testWidgets('TabController state management works correctly',
        (WidgetTester tester) async {
      // Create simple test data
      const testXmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR>
  <AR-PACKAGES>
    <AR-PACKAGE>
      <SHORT-NAME>Test</SHORT-NAME>
    </AR-PACKAGE>
  </AR-PACKAGES>
</AUTOSAR>''';

      const arxmlLoader = ARXMLFileLoader();
      final nodes = arxmlLoader.parseXmlContent(testXmlContent);

      // Build app with test provider
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileTabsProvider
                .overrideWith((ref) => TestFileTabsNotifier(ref, nodes)),
          ],
          child: const app.XmlExplorerApp(),
        ),
      );
      // Bounded pumps instead of pumpAndSettle
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // Get the notifier and simulate file loading
      final container = ProviderScope.containerOf(
          tester.element(find.byType(app.XmlExplorerApp)));
      final notifier =
          container.read(fileTabsProvider.notifier) as TestFileTabsNotifier;

      print('🧪 Testing TabController state management');

      // Initially should have no tabs
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Open a file to begin'), findsOneWidget);

      // Simulate loading a file
      await notifier.simulateFileLoad();
      // Pump a few frames
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // Should now have tabs
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);

      print('✅ TabController state management test passed');
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}

// Test notifier that can simulate file loading without file picker
class TestFileTabsNotifier extends FileTabsNotifier {
  final List<ElementNode> testNodes;
  final Ref _testRef;

  TestFileTabsNotifier(this._testRef, this.testNodes) : super(_testRef);

  Future<void> simulateFileLoad() async {
    print('🧪 TestFileTabsNotifier: Starting file load simulation');

    try {
      // Set loading state
      _testRef.read(loadingStateProvider.notifier).state = true;

      print('🧪 TestFileTabsNotifier: Loading state set to true');

      // Create a new tab with test data
      final newTab = FileTabState(
        path: 'test_file.arxml',
        treeStateProvider: arxmlTreeStateProvider(testNodes),
        xsdParser: null, // No XSD for test
      );

      // Add the tab
      state = [...state, newTab];
      _testRef.read(activeTabIndexProvider.notifier).state = state.length - 1;

      print(
          '🧪 TestFileTabsNotifier: Tab added, state.length = ${state.length}');

      // Removed artificial delay to prevent test hangs
    } catch (e, stackTrace) {
      print('❌ TestFileTabsNotifier ERROR: $e');
      print('Stack trace: $stackTrace');
    } finally {
      // Clear loading state
      _testRef.read(loadingStateProvider.notifier).state = false;
      print('🧪 TestFileTabsNotifier: Loading state set to false');
    }
  }
}
