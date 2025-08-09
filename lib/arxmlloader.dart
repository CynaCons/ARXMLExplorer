import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'elementnode.dart';
import 'package:xml/xml.dart';

class ARXMLFileLoader {
  const ARXMLFileLoader();

  Future<List<ElementNode>> openFile([String? filePath]) async {
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

      retval = parseXmlContent(fileContent);
    } else {
      developer.log("ERROR - User cancelled the file picker");
    }

    // retval = _processNodes(retval);

    return retval;
  }

  List<ElementNode> parseXmlContent(String input) {
    List<ElementNode> retval = [];

    final document = XmlDocument.parse(input);

    for (var element in document.childElements) {
      retval.addAll(_parseXmlElement(element, 0));
    }

    return retval;
  }

  List<ElementNode> _parseXmlElement(XmlElement element, int depth) {
    List<ElementNode> rootNodes = [];
    var stack = <(XmlElement, List<ElementNode>, int)>[(element, rootNodes, depth)];

    while (stack.isNotEmpty) {
      var (currentElement, parentChildren, currentDepth) = stack.removeLast();
      
      String elementText = currentElement.name.toString();
      List<ElementNode> newChildren = [];

      ElementNode newNode = ElementNode(
          elementText: elementText,
          depth: currentDepth,
          children: newChildren);

      if (elementText == "DEFINITION-REF" || elementText == "SHORT-NAME") {
        newNode.isCollapsed = true;
      }
      
      parentChildren.add(newNode);

      if (currentElement.children.length == 1 && currentElement.children.first is XmlText) {
        final textNode = currentElement.children.first as XmlText;
        final textChild = ElementNode(
            elementText: textNode.text,
            children: const [],
            depth: currentDepth + 1);
        newChildren.add(textChild);
      } else {
        // Add children to the stack in reverse order to process them correctly
        for (var child in currentElement.childElements.toList().reversed) {
          stack.add((child, newChildren, currentDepth + 1));
        }
      }
    }
    return rootNodes;
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
