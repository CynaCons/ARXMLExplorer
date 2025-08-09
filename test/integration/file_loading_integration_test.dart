import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:arxml_explorer/main.dart' as app;
import 'package:arxml_explorer/main.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/arxmlloader.dart';
import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/elementnodewidget.dart';

void main() {
  group('File Loading Integration Tests', () {
    testWidgets('App loads and shows initial state correctly',
        (WidgetTester tester) async {
      print('🧪 TEST START: App loads and shows initial state correctly');

      // Build the app
      print('🏗️ Building app widget...');
      await tester.pumpWidget(const ProviderScope(child: app.XmlExplorerApp()));
      print('⏳ Waiting for app to settle...');
      await tester.pumpAndSettle();
      print('✅ App built and settled');

      // Verify initial state
      print('🔍 Verifying initial state...');
      expect(find.text('ARXML Explorer'), findsOneWidget);
      expect(find.text('Open a file to begin'), findsOneWidget);
      expect(find.byIcon(Icons.file_open), findsOneWidget);

      print('✅ Initial app state verified - TEST PASSED');
    });

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
      print('⏳ Waiting for app to settle...');
      await tester.pumpAndSettle();

      print('🚀 App built with test data');

      // Verify initial state
      print('🔍 Verifying initial state...');
      expect(find.text('ARXML Explorer'), findsOneWidget);

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
      await tester.pumpAndSettle();

      print('📁 File loading simulated');

      // Wait for any delayed operations
      print('⏳ Waiting for delayed operations...');
      await tester.pump(const Duration(milliseconds: 500));

      // Debug: Print all widgets to see what's actually rendered
      print('🔍 Debugging widget tree...');

      // Verify that the file was loaded and UI is displayed
      // Check for tab presence
      print('🔍 Looking for TabBar...');
      expect(find.byType(TabBar), findsOneWidget);
      print('🔍 Looking for TabBarView...');
      expect(find.byType(TabBarView), findsOneWidget);

      print('🔍 Looking for element widgets...');

      // Check for element nodes in the tree
      print('🔍 Looking for ScrollablePositionedList...');
      expect(find.byType(ScrollablePositionedList), findsOneWidget);

      // Look for ElementNodeWidget instances
      print('🔍 Looking for ElementNodeWidget...');
      expect(find.byType(ElementNodeWidget), findsAtLeastNWidgets(1));

      // Look for the root AUTOSAR element
      print('🔍 Looking for AUTOSAR text...');
      expect(find.textContaining('AUTOSAR'), findsAtLeastNWidgets(1));

      print(
          '✅ File loading integration test completed successfully - TEST PASSED');
    });

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Should now have tabs
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);

      print('✅ TabController state management test passed');
    });
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

      // Small delay to simulate file processing
      await Future.delayed(const Duration(milliseconds: 100));
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
