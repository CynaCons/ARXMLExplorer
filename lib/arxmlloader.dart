import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'elementnode.dart';
import 'package:xml/xml.dart';

import 'elementnodecontroller.dart';

class ARXMLFileLoader {
  const ARXMLFileLoader();

  Future<List<ElementNode>> openFile(ElementNodeController controller,
      [String? filePath]) async {
    List<ElementNode> retval = [];
    developer.log("Opening a file");

    if (filePath == null) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        filePath = result.files.single.path;
      }
    }

    if (filePath != null) {
      File file = File(filePath);

      final fileContent = file.readAsStringSync();

      retval = parseXmlContent(fileContent, controller);
    } else {
      developer.log("ERROR - User cancelled the file picker");
    }

    // retval = _processNodes(retval);

    return retval;
  }

  List<ElementNode> parseXmlContent(
      String input, ElementNodeController controller) {
    List<ElementNode> retval = [];

    final document = XmlDocument.parse(input);

    for (var element in document.childElements) {
      retval.addAll(_parseXmlElement(element, 0, controller));
    }

    return retval;
  }

  List<ElementNode> _parseXmlElement(
      XmlElement element, int depth, ElementNodeController controller) {
    List<ElementNode> retval = [];

    // Increment the depth each time we recurse one level deeper
    depth++;

    // Properties for the new ElementNode
    String elementText = "default value";
    List<ElementNode> children = [];

    // If node is an XmlElement, then look for children
    if (element.nodeType == XmlNodeType.ELEMENT) {
      // If there are children, then recurse
      if (element.children.length > 1) {
        List<ElementNode> childrenElements = [];
        for (var child in element.childElements) {
          childrenElements.addAll(_parseXmlElement(child, depth, controller));
        }
        elementText = element.name.toString();
        children = childrenElements;
      } else if (element.children.length == 1) {
        /* Handle the case where the only children is a text node */
        if (element.children.first is XmlText) {
          List<ElementNode> listChildText = [];
          listChildText.add(ElementNode(
              elementText: element.children.first.text,
              children: const [],
              depth: depth + 1,
              nodeController: controller,
              onCollapseStateChange: controller.onCollapseStateChanged,
              onSelected: controller.onSelected));

          elementText = element.name.toString();
          children = listChildText;
          depth = depth;
        }
      } else {
        // If there are no children, return a TreeNode
        elementText = element.name.toString();
        children = const [];
        depth = depth;
      }

      ElementNode newNode = ElementNode(
          elementText: elementText,
          depth: depth,
          children: children,
          nodeController: controller,
          onCollapseStateChange: controller.onCollapseStateChanged,
          onSelected: controller.onSelected);
      if (elementText == "DEFINITION-REF" || elementText == "SHORT-NAME") {
        newNode.isCollapsed = true;
      }
      retval.add(newNode);
    }

    return retval;
  }

  String toXmlString(List<ElementNode> nodes) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    for (var node in nodes) {
      _buildXml(builder, node);
    }
    return builder.buildDocument().toXmlString(pretty: true);
  }

  void _buildXml(XmlBuilder builder, ElementNode node) {
    if (node.children.isEmpty) {
      builder.element(node.elementText, nest: () {});
    } else {
      if (node.children.length == 1 &&
          node.children.first.children.isEmpty) {
        builder.element(node.elementText,
            nest: node.children.first.elementText);
      } else {
        builder.element(node.elementText, nest: () {
          for (var child in node.children) {
            _buildXml(builder, child);
          }
        });
      }
    }
  }
}
