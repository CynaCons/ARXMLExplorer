import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter_application_1/elementnodecontroller.dart';

/// TODO The function getChild is misleading. IF given a requestedIndex == 0 it returns the node itself and not a child

const gNewImplementation = false;

class ElementNode {
  String elementText;
  List<ElementNode> children;
  int depth;
  int? _lengthCache;
  int id;
  bool isCollapsed = false;
  bool isSelected = false;
  bool isVisible = true;
  String shortname = "";
  String definitionRef = "";
  void Function(int, bool)? onCollapseStateChange;
  void Function(int, bool)? onSelected;
  ElementNodeController nodeController;

  ElementNode(
      {this.elementText = "",
      this.children = const [],
      this.depth = 1,
      this.onCollapseStateChange,
      this.onSelected,
      this.id = 0,
      required this.nodeController});

  ElementNode getChild(int requestedIndex, int currentIndex) {
    ElementNode retval = this;

    if (requestedIndex == currentIndex) {
      // Do nothing - current node will be returned
    } else if (requestedIndex > currentIndex) {
      // Increment the index, we're going deeper in the node
      for (var child in children) {
        // Check if the requested node is part of the child tree or not
        if (currentIndex + child.length >= requestedIndex) {
          currentIndex++;
          retval = child.getChild(requestedIndex, currentIndex);
          break;
        } else {
          // Skip the children and increment the index by the skipped child length
          currentIndex += child.length;
        }
      }
    } else {
      developer.log(
          "Impossible case detected with requestedIndex $requestedIndex and currentIndex $currentIndex");
    }

    return retval;
  }

  /// Getter for length of the children of this node
  int get length {
    int retval;

    if (_lengthCache != null) {
      retval = _lengthCache ?? 0;
    } else {
      retval = 1;
      for (var child in children) {
        retval += child.length;
      }
      _lengthCache = retval;
    }
    return retval;
  }

  int get visibleLength {
    var retval = 1;

    if (isCollapsed == false) {
      for (var child in children) {
        if (isCollapsed == true) {
          retval += 1;
        } else {
          retval += child.visibleLength;
        }
      }
    }

    return retval;
  }

  int get uncollapsedLength {
    // Base uncollapsedLength for a node is 1
    int retval = 1;

    // For each child
    for (var child in children) {
      if (child.isCollapsed == true) {
        // If child is collapsed, then its size is 1
        retval += 1;
      } else {
        // If child is uncollasped, then add the size of the child too
        retval += child.uncollapsedLength;
      }
    }
    return retval;
  }

  ///
  /// Returns the value in the first child node, which is maybe a ShortName
  ///
  String getShortName() {
    String retval = "";

    if (children.isEmpty) {
      throw ErrorDescription(
          "operation getShortName called on a node without children");
    } else {
      retval = children.first.elementText;
    }
    return retval;
  }

  ///
  /// Checks if the second container is a DefinitionRef, and returns the value if so
  String getDefinitionRef() {
    String retval = ""; // Default value is empty string

    if (children.isEmpty) {
      throw ErrorDescription(
          "operation getDefinitionRef called on a node without children");
    } else {
      if (elementText == "DEFINITION-REF") {
        retval = children.first.elementText;
      }
    }

    return retval;
  }

  void invalidateLength() {
    _lengthCache = null;
  }
}
