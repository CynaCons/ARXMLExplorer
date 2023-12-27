/// ElementNodeController is the controller of an ElementNode structure
///
/// The core of this class is the rootNodesList which contains the list of root
/// nodes for the structure. The rootNodeList shall be constructed first then
/// passed to the ElementNodeController via the controller
///

import "dart:developer" as developer;

// Self-made packages
import 'package:ARXMLExplorer/elementnodearxmlprocessor.dart';

import "elementnode.dart";

const gNewImplementation = true;

class ElementNodeController {
  late List<ElementNode> rootNodesList;
  Map<int, ElementNode> _nodeCache = <int, ElementNode>{};
  Map<int, ElementNode> _flatMap = <int, ElementNode>{};
  final ElementNodeARXMLProcessor _arxmlProcessor =
      const ElementNodeARXMLProcessor();
  int _idLastSelectedNode = -1;

  late void Function() requestRebuildCallback;

  ElementNodeController();

  void init(List<ElementNode> rootNodesList, void Function() rebuildCallback) {
    int index = 0;

    // Reset the _nodeCahe map
    _nodeCache = <int, ElementNode>{};

    for (var rootNode in rootNodesList) {
      _nodeCache[index] = rootNode;
      _nodeCache[index]?.onCollapseStateChange = onCollapseStateChanged;
      _nodeCache[index]?.onSelected = onSelected;
      rootNode.id = index;
      index++;
      for (int i = 1; i < rootNode.length; i++) {
        _nodeCache[index] = rootNode.getChild(i, 0);
        _nodeCache[index]?.id = index;
        _nodeCache[index]?.onCollapseStateChange = onCollapseStateChanged;
        _nodeCache[index]?.onSelected = onSelected;
        index++;
      }
    }

    // Store the original nodes in the FlatMap
    _flatMap = Map.from(_nodeCache);

    // Set the RequestRebuildCallback coming from the Nodes
    requestRebuildCallback = rebuildCallback;
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
    rebuildNodeCacheAfterNodeCollapseChange(id);

    // Invert the isCollapsed state
    _flatMap[id]!.isCollapsed = !_flatMap[id]!.isCollapsed;
  }

  void rebuildNodeCacheAfterNodeCollapseChange(int id) {
    Map<int, ElementNode> lNodeCache = <int, ElementNode>{};
    int lIdxCollapsedNode = 0;
    bool currentState = _flatMap[id]!.isCollapsed;

    // ------------------- Rebuild the NodeCache
    // First, takeover the nodes which are before the collapsed node
    var lIdx = 0; // Index for the next free slot in the new lNodeCache
    for (var node in _nodeCache.values) {
      lNodeCache[lIdx] = node;
      if (node.id == id) {
        // Exit condition when the node is found
        lIdxCollapsedNode = lIdx;
        // Takeover the node being collapsed
        break;
      }
      lIdx++;
    }
    var lVisibleLength = _nodeCache[lIdxCollapsedNode]!.visibleLength;
    var totalLength = _nodeCache.values.length;
    var lUncollapsedLength = _nodeCache[lIdxCollapsedNode]!.uncollapsedLength;
    // The visibleLength includes the length of the element itself
    var lVisibleCollapsingLength = lVisibleLength - 1;

    // Increment to have the lIdx pointing to the next free slot (next slot after the collapsed node)
    lIdx++;

    // Then, starting from index apply the displacement based on child size
    if (currentState == false) {
      // If collapsing
      for (var i = lIdx; i < (totalLength - lVisibleCollapsingLength); i++) {
        if (i + (lVisibleCollapsingLength) <= totalLength) {
          lNodeCache[i] = _nodeCache[i + lVisibleCollapsingLength]!;
          // lNodeCache[i]!.id = i;
        }
      }
    } else {
      // If uncollapsing
      // Reload the childs of the collapsed node
      var lNodeUncollapsed = _nodeCache[lIdxCollapsedNode]!;
      int lFlatMapNextNodeIdx = lNodeUncollapsed.id + 1;
      for (var i = 0; i < lUncollapsedLength - 1; i++, lIdx++) {
        var lNodeActive = _flatMap[lFlatMapNextNodeIdx]!;

        lNodeCache[lIdx] = _flatMap[lFlatMapNextNodeIdx]!;
        // lNodeCache[lIdx]!.id = lIdx;
        if (lNodeActive.isCollapsed == false) {
          lFlatMapNextNodeIdx += 1;
        } else {
          lFlatMapNextNodeIdx += lNodeActive.uncollapsedLength;
        }
      }

      for (var i = lIdxCollapsedNode + lVisibleLength;
          i < totalLength;
          i++, lIdx++) {
        lNodeCache[lIdx] = _nodeCache[i]!;
        // lNodeCache[lIdx]!.id = lIdx;
      }
    }

    _nodeCache = Map.from(lNodeCache);

    requestRebuildCallback();
  }
}
