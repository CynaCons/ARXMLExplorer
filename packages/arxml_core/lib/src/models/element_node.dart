/// Core model representing a parsed ARXML element in the in‑memory tree.
/// Pure data: no Flutter imports, UI flags kept minimal.
class ElementNode {
  String elementText;
  List<ElementNode> children;
  int depth;
  int? _lengthCache;
  int id = 0;
  bool isCollapsed = false;
  ElementNode? parent; // runtime-assigned for traversal
  // Marks nodes that represent text/value content rather than an XML element
  bool isValueNode = false;

  ElementNode({
    this.elementText = '',
    this.children = const [],
    this.depth = 1,
    this.isValueNode = false,
  });

  int get length {
    if (_lengthCache != null) return _lengthCache!;
    var total = 1;
    for (final c in children) {
      total += c.length;
    }
    _lengthCache = total;
    return total;
  }

  void invalidateLength() => _lengthCache = null;
}
