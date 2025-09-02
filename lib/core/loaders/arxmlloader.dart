import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../models/element_node.dart';
import '../xml/arxml_loader/parser.dart';
import '../xml/arxml_loader/serializer.dart';

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

  List<ElementNode> parseXmlContent(String input) {
    // ignore: avoid_print
    print('[loader] parseXmlContent len=' + input.length.toString());
    final nodes = const ArxmlParser().parseXmlContent(input);
    // ignore: avoid_print
    print('[loader] parsed root=' + nodes.length.toString());
    return nodes;
  }

  String toXmlString(List<ElementNode> nodes) =>
      const ArxmlSerializer().toXmlString(nodes);
}
