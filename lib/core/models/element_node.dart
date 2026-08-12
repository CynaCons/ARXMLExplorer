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
  // New: marks nodes that represent text/value content rather than an XML element
  bool isValueNode = false;

  ElementNode({
    this.elementText = '',
    this.children = const [],
    this.depth = 1,
    this.isValueNode = false,
  });

  /// Total node count of the subtree rooted here, memoised.
  int get length {
    if (_lengthCache != null) return _lengthCache!;
    var total = 1;
    for (final c in children) {
      total += c.length;
    }
    _lengthCache = total;
    return total;
  }

  /// Drops the memoised subtree size for this node *and every ancestor*.
  ///
  /// Clearing only the node's own cache left every ancestor reporting a stale
  /// count after an edit, because each parent's total was computed from the
  /// child's pre-edit value.
  void invalidateLength() {
    ElementNode? node = this;
    while (node != null) {
      node._lengthCache = null;
      node = node.parent;
    }
  }
}
