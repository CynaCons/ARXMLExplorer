import 'package:arxml_explorer/elementnode.dart';

/// Minimal controller used by legacy tests. It flattens nodes and exposes
/// a couple of simple properties queried by tests.
class ElementNodeController {
  int _itemCount = 0;
  final Map<int, ElementNode> _flatMap = {};

  int get itemCount => _itemCount;

  /// Iterable view of flattened nodes used in tests.
  Iterable<ElementNode> get flatMapValues => _flatMap.values;

  /// Initialize internal flattened map and assign stable incremental ids.
  /// onUpdate is invoked once at the end to mimic UI notifications.
  void init(
    List<ElementNode> nodes,
    void Function() onUpdate,
    Future<dynamic> Function(int id) scrollToId,
  ) {
    _flatMap.clear();
    int nextId = 0;

    void walk(ElementNode node, [ElementNode? parent]) {
      node.parent = parent;
      node.id = nextId++;
      _flatMap[node.id] = node;
      for (final c in node.children) {
        walk(c, node);
      }
    }

    for (final n in nodes) {
      walk(n, null);
    }

    _itemCount = _flatMap.length;
    // Notify once to emulate controller behavior in app code.
    try {
      onUpdate();
    } catch (_) {
      // ignore
    }
  }
}
