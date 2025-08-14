import '../../../../core/models/element_node.dart';
import 'arxml_edit_command.dart';

class DeleteNodeCommand implements ArxmlEditCommand {
  final ElementNode parent;
  final ElementNode node;
  final int index;
  DeleteNodeCommand(this.parent, this.node, this.index);
  @override
  void apply() {
    parent.children = [...parent.children]..remove(node);
  }

  @override
  void revert() {
    final list = [...parent.children];
    list.insert(index, node);
    parent.children = list;
    node.parent = parent;
  }

  @override
  String description() => 'Delete node';

  @override
  bool isStructural() => true;
}
