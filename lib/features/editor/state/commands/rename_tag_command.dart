import '../../../../core/models/element_node.dart';
import 'arxml_edit_command.dart';

class RenameTagCommand implements ArxmlEditCommand {
  final ElementNode node;
  final String oldTag;
  final String newTag;
  RenameTagCommand(this.node, this.oldTag, this.newTag);
  @override
  void apply() {
    node.elementText = newTag;
  }

  @override
  void revert() {
    node.elementText = oldTag;
  }

  @override
  String description() => 'Rename tag';

  @override
  bool isStructural() => true;
}
