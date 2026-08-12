import 'dart:io';

import '../diagnostics/log.dart';
import '../models/element_node.dart';
import '../xml/arxml_loader/parser.dart';
import '../xml/arxml_loader/serializer.dart';

/// Loads and serialises ARXML documents.
///
/// Takes a path or content only. Choosing *which* file to open is a
/// presentation concern and lives in the application layer
/// (`FileTabsNotifier.openNewFile`); this class used to reach for
/// `FilePicker` directly, which pulled a platform UI plugin into `core` and
/// made the loader unusable headless.
class ARXMLFileLoader {
  const ARXMLFileLoader();

  /// Reads and parses [filePath].
  ///
  /// Returns an empty list when the file cannot be read; the reason is logged.
  Future<List<ElementNode>> openFile(String filePath) async {
    try {
      final fileContent = await File(filePath).readAsString();
      return parseXmlContent(fileContent);
    } on FileSystemException catch (e, st) {
      Log.error('loader', 'Failed to read $filePath', e, st);
      return const [];
    }
  }

  List<ElementNode> parseXmlContent(String input) {
    Log.debug('loader', 'parse ${input.length} chars');
    final nodes = const ArxmlParser().parseXmlContent(input);
    Log.debug('loader', 'parsed ${nodes.length} root nodes');
    return nodes;
  }

  String toXmlString(List<ElementNode> nodes) =>
      const ArxmlSerializer().toXmlString(nodes);
}
