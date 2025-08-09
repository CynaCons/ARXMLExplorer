import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';

const gNewImplementation = false;

class ElementNode {
  String elementText;
  List<ElementNode> children;
  int depth;
  int? _lengthCache;
  int id = 0;
  bool isCollapsed = false;
  bool isSelected = false;
  bool isVisible = true;
  String shortname = "";
  String definitionRef = "";
  ElementNode? parent;

  ElementNode({
    this.elementText = "",
    this.children = const [],
    this.depth = 1,
  });

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
        retval += child.visibleLength;
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
