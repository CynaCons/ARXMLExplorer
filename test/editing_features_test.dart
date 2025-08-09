import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/arxmlloader.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'dart:io';

void main() {
  group('Editing and Persistence', () {
    late ProviderContainer container;
    late List<ElementNode> nodes;

    setUp(() async {
      final fileContent = await File('test/res/complex_nested.arxml').readAsString();
      nodes = const ARXMLFileLoader().parseXmlContent(fileContent);
      container = ProviderContainer();
    });

    test('Can delete a node from the state', () {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final nodeToDelete = notifier.state.flatMap.values.firstWhere((n) => n.elementText == 'NestedContainerL2');
      final parent = nodeToDelete.parent!;
      
      notifier.deleteNode(nodeToDelete.id);

      expect(parent.children.contains(nodeToDelete), isFalse);
    });

    test('Can edit a node value in the state', () {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final nodeToEdit = notifier.state.flatMap.values.firstWhere((n) => n.elementText == 'VALUE');
      
      expect(nodeToEdit.children.first.elementText, '123456789');

      notifier.editNodeValue(nodeToEdit.id, '987654321');

      expect(nodeToEdit.children.first.elementText, '987654321');
    });

    test('Can save and reload a modified file', () async {
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      final nodeToEdit = notifier.state.flatMap.values.firstWhere((n) => n.elementText == 'VALUE');
      
      // 1. Edit the value
      notifier.editNodeValue(nodeToEdit.id, 'ValueWasEdited');

      // 2. Save the file
      final tempPath = './test/res/temp_save_test.arxml';
      final xmlString = const ARXMLFileLoader().toXmlString(notifier.state.rootNodes);
      await File(tempPath).writeAsString(xmlString);

      // 3. Reload the file and check the value
      final newFileContent = await File(tempPath).readAsString();
      final newNodes = const ARXMLFileLoader().parseXmlContent(newFileContent);
      final newNotifier = container.read(arxmlTreeStateProvider(newNodes).notifier);
      
      final newNodeToVerify = newNotifier.state.flatMap.values.firstWhere((n) => n.elementText == 'VALUE');

      expect(newNodeToVerify.children.first.elementText, 'ValueWasEdited');

      // Cleanup
      await File(tempPath).delete();
    });
  });
}
