import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'elementnode.dart';
import 'core/xml/arxml_loader/parser.dart';
import 'core/xml/arxml_loader/serializer.dart';

class ARXMLFileLoader {
  const ARXMLFileLoader();

  Future<List<ElementNode>> openFile([String? filePath]) async {
    List<ElementNode> retval = [];
    developer.log("Opening a file");

    if (filePath == null) {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        filePath = result.files.single.path;
      }
    }

    if (filePath != null) {
      final file = File(filePath);

      final fileContent = file.readAsStringSync();

      retval = parseXmlContent(fileContent);
    } else {
      developer.log("ERROR - User cancelled the file picker");
    }

    return retval;
  }

  List<ElementNode> parseXmlContent(String input) =>
      const ArxmlParser().parseXmlContent(input);
  String toXmlString(List<ElementNode> nodes) =>
      const ArxmlSerializer().toXmlString(nodes);
}
