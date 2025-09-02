import 'dart:io';
import 'package:arxml_explorer/core/core.dart';

void main() async {
  final sw = Stopwatch()..start();
  final content = await File('test/res/complex_nested.arxml').readAsString();
  final nodes = const ARXMLFileLoader().parseXmlContent(content);
  sw.stop();
  var count = 0;
  void walk(ElementNode n) {
    count++;
    for (final c in n.children) walk(c);
  }

  for (final r in nodes) {
    walk(r);
  }
  print(
      'Parsed nodes: root=${nodes.length} total=$count in ${sw.elapsedMilliseconds}ms');
}
