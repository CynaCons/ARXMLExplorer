import "dart:developer" as developer;

// Self-made packages
import "elementnode.dart";
import "elementnodecontroller.dart";

class ElementNodeARXMLProcessor {
  /// Constructor
  const ElementNodeARXMLProcessor();

  void processNodes(ElementNodeController nodeController) {
    List<ElementNode> lNodesList;

    lNodesList = nodeController.nodes;
    developer.log("ARXMLProcessor: processNodes is reached");

    var lIdx = 0;
    var lLength = nodeController.itemCount;

    while (lIdx < lLength) {
      var node = nodeController.getNode(lIdx)!;
      if (node.children.isNotEmpty) {
        for (var child in node.children) {
          if (child.elementText.contains("DEFINITION-REF")) {
            node.definitionRef = child.getDefinitionRef();
            nodeController.collapseNode(child.id);
          }

          if (child.elementText == "SHORT-NAME") {
            node.shortname = child.getShortName();
            nodeController.collapseNode(child.id);
          }
        }
      }
      // Increment lIdx
      lIdx++;

      lLength = nodeController.itemCount;
    }
  }
}
