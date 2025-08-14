import 'package:xml/xml.dart';
import 'package:arxml_explorer/core/models/element_node.dart';

class ArxmlParser {
  const ArxmlParser();

  List<ElementNode> parseXmlContent(String input) {
    final document = XmlDocument.parse(input);
    final roots = <ElementNode>[];
    for (final element in document.childElements) {
      roots.addAll(_parseXmlElement(element, 0));
    }
    return roots;
  }

  List<ElementNode> _parseXmlElement(XmlElement element, int depth) {
    final rootNodes = <ElementNode>[];
    final stack = <(XmlElement, List<ElementNode>, int)>[
      (element, rootNodes, depth)
    ];

    while (stack.isNotEmpty) {
      final (currentElement, parentChildren, currentDepth) = stack.removeLast();
      final elementText = currentElement.name.toString();
      final newChildren = <ElementNode>[];

      final newNode = ElementNode(
        elementText: elementText,
        depth: currentDepth,
        children: newChildren,
      );

      if (elementText == 'DEFINITION-REF' || elementText == 'SHORT-NAME') {
        newNode.isCollapsed = true;
      }

      parentChildren.add(newNode);

      if (currentElement.children.length == 1 &&
          currentElement.children.first is XmlText) {
        final textNode = currentElement.children.first as XmlText;
        final textChild = ElementNode(
          elementText: textNode.text,
          children: const [],
          depth: currentDepth + 1,
          isValueNode: true,
        );
        newChildren.add(textChild);
      } else {
        for (final child in currentElement.childElements.toList().reversed) {
          stack.add((child, newChildren, currentDepth + 1));
        }
      }
    }
    return rootNodes;
  }
}
