import 'package:xml/xml.dart';
import '../../models/element_node.dart';

class ArxmlSerializer {
  const ArxmlSerializer();

  String toXmlString(List<ElementNode> nodes) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    for (final node in nodes) {
      _buildXml(builder, node);
    }
    return builder.buildDocument().toXmlString(pretty: true);
  }

  void _buildXml(XmlBuilder builder, ElementNode node) {
    if (node.children.isEmpty) {
      builder.element(node.elementText, nest: () {});
    } else if (node.children.length == 1 &&
        node.children.first.children.isEmpty) {
      builder.element(node.elementText, nest: node.children.first.elementText);
    } else {
      builder.element(node.elementText, nest: () {
        for (final child in node.children) {
          _buildXml(builder, child);
        }
      });
    }
  }
}
