import 'package:xml/xml.dart';

class XsdParser {
  final XmlDocument document;

  XsdParser(String xsdContent) : document = XmlDocument.parse(xsdContent);

  List<String> getValidChildElements(String parentElementName) {
    final List<String> validChildElements = [];
    final parentElement = document.findAllElements(parentElementName).firstOrNull;

    if (parentElement != null) {
      final complexType = parentElement.findElements('xs:complexType').firstOrNull;
      if (complexType != null) {
        final sequence = complexType.findElements('xs:sequence').firstOrNull;
        if (sequence != null) {
          final childElements = sequence.findElements('xs:element');
          for (var childElement in childElements) {
            final childElementName = childElement.getAttribute('name');
            if (childElementName != null) {
              validChildElements.add(childElementName);
            }
          }
        }
      }
    }

    return validChildElements;
  }
}
