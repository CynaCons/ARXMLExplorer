import '../../../../core/models/element_node.dart';

/// Test-only simplified controller preserved for backward-compatible tests.
class ElementNodeController {
  int _itemCount = 0;
  final Map<int, ElementNode> _flatMap = {};

  int get itemCount => _itemCount;
  Iterable<ElementNode> get flatMapValues => _flatMap.values;

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
    try {
      onUpdate();
    } catch (_) {}
  }
}
