/// ElementNodeController is the controller of an ElementNode structure
///
/// The core of this class is the rootNodesList which contains the list of root
/// nodes for the structure. The rootNodeList shall be constructed first then
/// passed to the ElementNodeController via the controller
///

import "dart:developer" as developer;

// Self-made packages
import 'package:flutter_application_1/elementnodearxmlprocessor.dart';

import "elementnode.dart";

const gNewImplementation = true;

class ElementNodeController {
  late List<ElementNode> rootNodesList;
  Map<int, ElementNode> _nodeCache = <int, ElementNode>{};
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
    rebuildNodeCacheAfterNodeCollapseChange(id, newState);

    return;
  }

  void onSelected(int id, bool newIsSelected) {
    // #10 - Unselect the previous node
    if (_idLastSelectedNode > 0) {
      _nodeCache[_idLastSelectedNode]!.isSelected = false;
    }

    // #20 - Select the new mode
    _nodeCache[id]!.isSelected = newIsSelected;

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
    developer.log("Collapse Node hit for id $id");

    rebuildNodeCacheAfterNodeCollapseChange(id, _nodeCache[id]!.isCollapsed);

    // Invert the isCollapsed state
    _nodeCache[id]!.isCollapsed = !_nodeCache[id]!.isCollapsed;
  }

  ///
  /// TODO This function could be embedded inside the collapseNode function
  void rebuildNodeCacheAfterNodeCollapseChange(int id, bool newState) {
    // Then, starting from index apply the displacement based on child size
    if (newState == false) {
      // If collapsing, change the isVisible attribute for all childs
      recurseToChangeVisiblity(_nodeCache[id]!, false, true);
    } else {
      // If uncollapsing
      recurseToChangeVisiblity(_nodeCache[id]!, true, true);
    }

    requestRebuildCallback();
  }

  ///
  /// Function to recursively change the visiblity of a node and its children
  ///
  void recurseToChangeVisiblity(
      ElementNode node, bool newIsVisible, bool isFirst) {
    if (isFirst == false) {
      node.isVisible = newIsVisible;
    } else {
      isFirst = false;
    }

    if (node.children.isEmpty == true) {
      return;
    } else {
      for (var child in node.children) {
        recurseToChangeVisiblity(child, newIsVisible, isFirst);
      }
    }
  }
}
