import '../../../../core/models/element_node.dart';
import 'arxml_edit_command.dart';

class EditValueCommand implements ArxmlEditCommand {
  final ElementNode node;
  final String oldValue;
  final String newValue;
  EditValueCommand(this.node, this.oldValue, this.newValue);
  @override
  void apply() {
    node.children.isNotEmpty
        ? node.children.first.elementText = newValue
        : node.elementText = newValue;
  }

  @override
  void revert() {
    node.children.isNotEmpty
        ? node.children.first.elementText = oldValue
        : node.elementText = oldValue;
  }

  @override
  String description() => 'Edit value';

  @override
  bool isStructural() => false;
}
