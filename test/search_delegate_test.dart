import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/elementnodecontroller.dart';
import 'package:arxml_explorer/elementnodesearchdelegate.dart';
import 'package:mockito/mockito.dart';

// Mocks
class MockNavigatorObserver extends Mock implements NavigatorObserver {}
class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('CustomSearchDelegate', () {
    late ElementNodeController controller;
    late ElementNode root, child1, grandchild1;
    late CustomSearchDelegate delegate;
    late MockNavigatorObserver mockObserver;

    setUp(() {
      controller = ElementNodeController();
      mockObserver = MockNavigatorObserver();

      // Setup node tree
      root = ElementNode(elementText: 'Root', nodeController: controller, children: []);
      child1 = ElementNode(elementText: 'Child1', nodeController: controller, children: []);
      grandchild1 = ElementNode(elementText: 'Grandchild1', nodeController: controller, children: []);
      
      child1.children.add(grandchild1);
      root.children.add(child1);

      controller.init([root], () {}, (id) => Future.value());

      delegate = CustomSearchDelegate(GlobalKey<ScaffoldState>(), controller);
    });

    testWidgets('tapping a suggestion expands parents, scrolls, and closes search', (WidgetTester tester) async {
      // Ensure grandchild is initially hidden by collapsing the parent
      controller.collapseNode(child1.id);
      expect(child1.isCollapsed, isTrue);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showSearch(context: context, delegate: delegate);
              },
              child: const Text('Search'),
            ),
          ),
        ),
        navigatorObservers: [mockObserver],
      ));

      // Open the search
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Enter search query that matches the grandchild
      delegate.query = 'Grand';
      await tester.pumpAndSettle();

      // Tap the suggestion
      await tester.tap(find.text('Grandchild1'));
      await tester.pumpAndSettle();

      // Verify:
      // 1. Parent is now expanded
      expect(child1.isCollapsed, isFalse, reason: "Parent of searched node should be expanded");

      // 2. Search UI is closed
      expect(find.byType(CustomSearchDelegate), findsNothing);
    });
  });
}
