/// ElementNodeController is the controller of an ElementNode structure
///
/// The core of this class is the rootNodesList which contains the list of root
/// nodes for the structure. The rootNodeList shall be constructed first then
/// passed to the ElementNodeController via the controller
///

import "dart:developer" as developer;


// Self-made packages


import "elementnode.dart";

const gNewImplementation = true;

class ElementNodeController {
  late List<ElementNode> rootNodesList;
  final Map<int, ElementNode> _nodeCache = <int, ElementNode>{};
  final Map<int, ElementNode> _flatMap = <int, ElementNode>{};

  Iterable<ElementNode> get flatMapValues => _flatMap.values;
  
  int _idLastSelectedNode = -1;

  late void Function() requestRebuildCallback;
  late Future<void> Function(int id) onScrollToNode;

  ElementNodeController();

  void init(List<ElementNode> rootNodesList, void Function() rebuildCallback, Future<void> Function(int id) scrollCallback) {
    this.rootNodesList = rootNodesList;
    _nodeCache.clear();
    _flatMap.clear(); // Clear flatMap as well
    int globalId = 0; // Use a global ID counter for _flatMap

    // Populate _flatMap with all nodes and assign unique IDs
    for (var rootNode in rootNodesList) {
      globalId = _populateFlatMap(rootNode, null, globalId);
    }

    // Now build the initial _nodeCache based on collapsed state
    _rebuildNodeCache();

    requestRebuildCallback = rebuildCallback;
    onScrollToNode = scrollCallback;
  }

  // Helper to populate _flatMap and assign IDs
  int _populateFlatMap(ElementNode node, ElementNode? parent, int currentId) {
    node.id = currentId; // Assign ID
    node.parent = parent; // Assign parent
    _flatMap[currentId] = node; // Add to flatMap
    node.onCollapseStateChange = onCollapseStateChanged; // Set callbacks
    node.onSelected = onSelected; // Set callbacks

    int nextId = currentId;
    for (var child in node.children) {
      nextId = _populateFlatMap(child, node, nextId + 1); // Recursively populate children
    }
    return nextId; // Return the last assigned ID in this subtree
  }

  int get itemCount {
    return _nodeCache.length;
  }

  ElementNode? getNode(requestedIndex) {
    return _nodeCache[requestedIndex];
  }

  List<ElementNode> get nodes {
    return List.from(_nodeCache.values);
  }

  void onCollapseStateChanged(int id, bool newState) {
    collapseNode(id);

    return;
  }

  void onSelected(int id, bool newIsSelected) {
    // #10 - Unselect the previous node
    if (_idLastSelectedNode > 0) {
      _flatMap[_idLastSelectedNode]!.isSelected = false;
    }

    // #20 - Select the new mode
    _flatMap[id]!.isSelected = newIsSelected;

    // #30 - Cache the id of the new selected node
    _idLastSelectedNode = id;

    // #40 - Request a rebuild
    requestRebuildCallback();

    // #50 - Log the currently selected node
    developer.log("Selected Node: $id");
  }

  ///
  /// Collapse a single node and update the node cache.
  ///
  /// NOTE: This method does to trigger a widget tree rebuild
  ///
  void collapseNode(int id) {
    // Invert the isCollapsed state
    _flatMap[id]!.isCollapsed = !_flatMap[id]!.isCollapsed;
    _rebuildNodeCache();
    requestRebuildCallback();
  }

  void rebuildNodeCacheAfterNodeCollapseChange(int id) {
    // Invert the isCollapsed state
    _flatMap[id]!.isCollapsed = !_flatMap[id]!.isCollapsed;
    _rebuildNodeCache();
    requestRebuildCallback();
  }

  void collapseAll() {
    for (var node in _flatMap.values) {
      node.isCollapsed = true;
    }
    _rebuildNodeCache();
    requestRebuildCallback();
  }

  void expandAll() {
    for (var node in _flatMap.values) {
      node.isCollapsed = false;
    }
    _rebuildNodeCache();
    requestRebuildCallback();
  }

  void expandUntilNode(int id) {
    var node = _flatMap[id];
    if (node == null) return;

    // Expand all parents of the node
    var parent = node.parent;
    while (parent != null) {
      if (parent.isCollapsed) {
        parent.isCollapsed = false;
      }
      parent = parent.parent;
    }
    _rebuildNodeCache();
    requestRebuildCallback();
  }

  void _rebuildNodeCache() {
    _nodeCache.clear();
    int index = 0;
    for (var rootNode in rootNodesList) {
      index = _addVisibleNodesToCache(rootNode, index);
    }
  }

  // Helper to add only visible nodes to _nodeCache
  int _addVisibleNodesToCache(ElementNode node, int currentIndex) {
    _nodeCache[currentIndex] = node;
    int nextIndex = currentIndex;
    if (!node.isCollapsed) {
      for (var child in node.children) {
        nextIndex = _addVisibleNodesToCache(child, nextIndex + 1);
      }
    }
    return nextIndex;
  }
}
