import '../../../../core/models/element_node.dart';
import 'arxml_edit_command.dart';

class ConvertTypeCommand implements ArxmlEditCommand {
  final ElementNode node;
  final String oldTag;
  final String newTag;
  final List<ElementNode> removedChildren;
  ConvertTypeCommand(this.node, this.oldTag, this.newTag, this.removedChildren);
  @override
  void apply() {
    node.elementText = newTag;
    // children already pruned when command created
  }

  @override
  void revert() {
    node.elementText = oldTag;
    if (removedChildren.isNotEmpty) {
      node.children = [...node.children, ...removedChildren];
      for (final c in removedChildren) {
        c.parent = node;
      }
    }
  }

  @override
  String description() => 'Convert type';

  @override
  bool isStructural() => true;
}
