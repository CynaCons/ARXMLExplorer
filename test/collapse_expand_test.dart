import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/elementnodecontroller.dart';
import 'package:arxml_explorer/elementnode.dart';

void main() {
  group('ElementNodeController Collapse/Expand', () {
    late ElementNodeController controller;
    late List<ElementNode> rootNodes;
    late int rebuildCallCount;
    late ElementNode node1, node1_1, node1_2, node1_1_1;

    setUp(() {
      rebuildCallCount = 0;
      controller = ElementNodeController();

      // Initialize a simple tree structure for testing
      node1 = ElementNode(elementText: 'Node1', nodeController: controller, children: []);
      node1_1 = ElementNode(elementText: 'Node1.1', nodeController: controller, children: []);
      node1_2 = ElementNode(elementText: 'Node1.2', nodeController: controller, children: []);
      node1_1_1 = ElementNode(elementText: 'Node1.1.1', nodeController: controller, children: []);

      node1_1.children.add(node1_1_1);
      node1.children.addAll([node1_1, node1_2]);

      rootNodes = [node1];

      controller.init(rootNodes, () { rebuildCallCount++; }, (id) => Future.value()); // Pass mock callbacks
    });

    test('init assigns unique IDs to all nodes', () {
      final allNodes = controller.flatMapValues.toList();
      final ids = allNodes.map((n) => n.id).toSet();
      expect(ids.length, equals(allNodes.length), reason: "Node IDs should be unique");
    });

    test('collapseNode collapses a child node and updates itemCount', () {
      // Pre-condition: Ensure the parent node (node1) is expanded
      expect(node1.isCollapsed, isFalse, reason: "Parent node should be expanded initially");
      
      // The node to collapse is node1_1, which is the second node in the visible list (index 1)
      final nodeToCollapse = controller.getNode(1);
      expect(nodeToCollapse, same(node1_1), reason: "Should get node1_1 at index 1");
      expect(nodeToCollapse!.isCollapsed, isFalse, reason: "Child node should not be collapsed initially");
      
      final initialItemCount = controller.itemCount;

      // Act: Collapse the child node
      controller.collapseNode(nodeToCollapse.id);

      // Assert
      expect(nodeToCollapse.isCollapsed, isTrue, reason: "Child node should now be collapsed");
      // Collapsing node1_1 should hide its child (node1_1_1), so 1 item should disappear.
      expect(controller.itemCount, equals(initialItemCount - 1), reason: "Item count should decrease by 1");
      expect(rebuildCallCount, equals(1), reason: "A rebuild should be requested");
    });

    test('collapseNode collapses a root node and updates itemCount', () {
      final nodeToCollapse = controller.getNode(0); // Node1
      expect(nodeToCollapse!.isCollapsed, isFalse); // Initially not collapsed
      final initialItemCount = controller.itemCount;

      controller.collapseNode(nodeToCollapse.id);
      expect(nodeToCollapse.isCollapsed, isTrue);
      // Node1 has 2 direct children (Node1.1, Node1.2) and one grandchild (Node1.1.1).
      // Collapsing Node1 should hide all 3 descendants.
      expect(controller.itemCount, equals(initialItemCount - 3));
      expect(rebuildCallCount, equals(1));
    });

    test('expandNode expands a node and updates itemCount', () {
      final nodeToExpand = controller.getNode(0); // Node1
      controller.collapseNode(nodeToExpand!.id); // Collapse first
      rebuildCallCount = 0; // Reset for this test
      expect(nodeToExpand.isCollapsed, isTrue);
      final collapsedItemCount = controller.itemCount;

      controller.collapseNode(nodeToExpand.id); // Call again to expand
      expect(nodeToExpand.isCollapsed, isFalse);
      // Node1 has 3 descendants. Expanding Node1 should show all 3.
      expect(controller.itemCount, equals(collapsedItemCount + 3));
      expect(rebuildCallCount, equals(1));
    });

    test('collapseAll collapses all nodes and updates itemCount', () {
      controller.collapseAll();
      for (var node in controller.flatMapValues) {
        expect(node.isCollapsed, isTrue);
      }
      expect(controller.itemCount, equals(rootNodes.length)); // Only root nodes visible
      expect(rebuildCallCount, equals(1));
    });

    test('expandAll expands all nodes and updates itemCount', () {
      controller.collapseAll(); // Collapse all first
      rebuildCallCount = 0; // Reset for this test

      controller.expandAll();
      for (var node in controller.flatMapValues) {
        expect(node.isCollapsed, isFalse);
      }
      // The total number of nodes in the test tree is 4.
      expect(controller.itemCount, equals(4));
      expect(rebuildCallCount, equals(1));
    });
  });
}
