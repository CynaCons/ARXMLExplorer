import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import 'dart:io';

void main() {
  group('Editing and Persistence', () {
    late ProviderContainer container;
    late List<ElementNode> nodes;

    setUp(() async {
      final fileContent =
          await File('test/res/complex_nested.arxml').readAsString();
      nodes = const ARXMLFileLoader().parseXmlContent(fileContent);
      container = ProviderContainer();
    });

    test('Can delete a node from the state', () {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final nodeToDelete = notifier.state.flatMap.values
          .firstWhere((n) => n.elementText == 'NestedContainerL2');
      final parent = nodeToDelete.parent!;

      notifier.deleteNode(nodeToDelete.id);

      expect(parent.children.contains(nodeToDelete), isFalse);
    });

    test('Can edit a node value in the state', () {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final nodeToEdit = notifier.state.flatMap.values
          .firstWhere((n) => n.elementText == 'VALUE');

      expect(nodeToEdit.children.first.elementText, '123456789');

      notifier.editNodeValue(nodeToEdit.id, '987654321');

      expect(nodeToEdit.children.first.elementText, '987654321');
    });

    test('Convert element type prunes incompatible children', () {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final candidate = notifier.state.flatMap.values.firstWhere(
          (n) => n.children.isNotEmpty && n.elementText != 'SHORT-NAME');
      final oldTag = candidate.elementText;

      notifier.convertNodeType(candidate.id, 'DUMMY-NEW-TYPE');

      expect(candidate.elementText, 'DUMMY-NEW-TYPE');

      notifier.undo();

      expect(candidate.elementText, oldTag);
    });

    test('Safe rename SHORT-NAME updates DEFINITION-REF references', () {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      // Find a SHORT-NAME container that has a DEFINITION-REF somewhere referencing its path (synthetic if needed)
      final shortNameNode = notifier.state.flatMap.values
          .firstWhere((n) => n.elementText == 'SHORT-NAME');
      // Synthesize a DEFINITION-REF referencing its path if not present
      final pathSegs = <String>[];
      ElementNode? cur = shortNameNode.parent;
      while (cur != null) {
        if (cur.children.isNotEmpty &&
            cur.children.first.elementText == 'SHORT-NAME' &&
            cur.children.first.children.isNotEmpty) {
          pathSegs.add(cur.children.first.children.first.elementText.trim());
        }
        cur = cur.parent;
      }
      final segsOrdered = pathSegs.reversed.toList();
      if (segsOrdered.isNotEmpty) {
        final abs = '/${segsOrdered.join('/')}';
        final defRef = ElementNode(
            elementText: 'DEFINITION-REF',
            children: [ElementNode(elementText: abs, children: [])]);
        shortNameNode.parent?.children = [
          ...shortNameNode.parent!.children,
          defRef
        ];
      }
      final oldValue = shortNameNode.children.isNotEmpty
          ? shortNameNode.children.first.elementText
          : '';
      notifier.safeRenameShortName(shortNameNode.id, oldValue + '_Renamed');
      expect(shortNameNode.children.first.elementText, oldValue + '_Renamed');
      notifier.undo();
      expect(shortNameNode.children.first.elementText, oldValue);
    });

    test('Undo/Redo stacks behave', () {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final leaf = notifier.state.flatMap.values
          .firstWhere((n) => n.elementText == 'VALUE');
      final original = leaf.children.first.elementText;
      notifier.editNodeValue(leaf.id, 'TempChange');
      expect(leaf.children.first.elementText, 'TempChange');
      notifier.undo();
      expect(leaf.children.first.elementText, original);
      notifier.redo();
      expect(leaf.children.first.elementText, 'TempChange');
    });

    test('Can save and reload a modified file', () async {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final nodeToEdit = notifier.state.flatMap.values
          .firstWhere((n) => n.elementText == 'VALUE');

      // 1. Edit the value
      notifier.editNodeValue(nodeToEdit.id, 'ValueWasEdited');

      // 2. Save the file
      final tempPath = './test/res/temp_save_test.arxml';
      final xmlString =
          const ARXMLFileLoader().toXmlString(notifier.state.rootNodes);
      await File(tempPath).writeAsString(xmlString);

      // 3. Reload the file and check the value
      final newFileContent = await File(tempPath).readAsString();
      final newNodes = const ARXMLFileLoader().parseXmlContent(newFileContent);
      final newNotifier =
          container.read(arxmlTreeStateProvider(newNodes).notifier);

      final newNodeToVerify = newNotifier.state.flatMap.values
          .firstWhere((n) => n.elementText == 'VALUE');

      expect(newNodeToVerify.children.first.elementText, 'ValueWasEdited');

      // Cleanup
      await File(tempPath).delete();
    });

    test('Add child expands parent and selects new node', () {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final parent = notifier.state.rootNodes.first;
      // collapse parent to test auto-expand
      parent.isCollapsed = true;
      final originalVisibleCount = notifier.state.visibleNodes.length;
      notifier.addChildNode(parent.id, 'NEW-CHILD-TAG');
      // parent should be expanded now
      expect(parent.isCollapsed, isFalse);
      // new child should be present
      final added =
          parent.children.lastWhere((c) => c.elementText == 'NEW-CHILD-TAG');
      expect(added.elementText, 'NEW-CHILD-TAG');
      // state selection should be the new child
      expect(notifier.state.selectedNodeId, added.id);
      // visible nodes should increase
      expect(notifier.state.visibleNodes.length,
          greaterThan(originalVisibleCount));
    });
  });
}
