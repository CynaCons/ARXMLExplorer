import '../../../../core/models/element_node.dart';
import 'arxml_edit_command.dart';

class AddChildCommand implements ArxmlEditCommand {
  final ElementNode parent;
  final ElementNode child;
  AddChildCommand(this.parent, this.child);
  @override
  void apply() {
    parent.children = [...parent.children, child];
    child.parent = parent;
  }

  @override
  void revert() {
    parent.children = parent.children.where((c) => c != child).toList();
  }

  @override
  String description() => 'Add child';

  @override
  bool isStructural() => true;
}
