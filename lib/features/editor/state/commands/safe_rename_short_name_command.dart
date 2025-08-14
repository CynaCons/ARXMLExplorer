import '../../../../core/models/element_node.dart';
import 'arxml_edit_command.dart';

class SafeRenameShortNameCommand implements ArxmlEditCommand {
  final ElementNode shortNameNode; // node with elementText == 'SHORT-NAME'
  final String oldValue;
  final String newValue;
  final List<ElementNode> updatedRefNodes;
  final List<String> oldRefValues;
  final List<String> newRefValues;
  SafeRenameShortNameCommand(this.shortNameNode, this.oldValue, this.newValue,
      this.updatedRefNodes, this.oldRefValues, this.newRefValues);
  @override
  void apply() {
    if (shortNameNode.children.isNotEmpty) {
      shortNameNode.children.first.elementText = newValue;
    }
    for (var i = 0; i < updatedRefNodes.length; i++) {
      final n = updatedRefNodes[i];
      if (n.children.isNotEmpty) {
        n.children.first.elementText = newRefValues[i];
      }
    }
  }

  @override
  void revert() {
    if (shortNameNode.children.isNotEmpty) {
      shortNameNode.children.first.elementText = oldValue;
    }
    for (var i = 0; i < updatedRefNodes.length; i++) {
      final n = updatedRefNodes[i];
      if (n.children.isNotEmpty) {
        n.children.first.elementText = oldRefValues[i];
      }
    }
  }

  @override
  String description() => 'Safe rename SHORT-NAME';

  @override
  bool isStructural() => false;
}
