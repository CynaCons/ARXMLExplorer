import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'elementnode.dart';
import 'dart:collection';

class ArxmlTreeState {
  final List<ElementNode> rootNodes;
  final UnmodifiableListView<ElementNode> visibleNodes;
  final Map<int, ElementNode> flatMap;
  final int? contextMenuNodeId;

  ArxmlTreeState({
    required this.rootNodes,
    required this.visibleNodes,
    required this.flatMap,
    this.contextMenuNodeId,
  });

  ArxmlTreeState copyWith({
    int? contextMenuNodeId,
    bool clearContextMenu = false,
  }) {
    return ArxmlTreeState(
      rootNodes: rootNodes,
      visibleNodes: visibleNodes,
      flatMap: flatMap,
      contextMenuNodeId:
          clearContextMenu ? null : contextMenuNodeId ?? this.contextMenuNodeId,
    );
  }
}

final arxmlTreeStateProvider = StateNotifierProvider.autoDispose
    .family<ArxmlTreeStateNotifier, ArxmlTreeState, List<ElementNode>>(
        (ref, initialNodes) {
  return ArxmlTreeStateNotifier(initialNodes);
});

class ArxmlTreeStateNotifier extends StateNotifier<ArxmlTreeState> {
  final List<ElementNode> initialNodes;
  ArxmlTreeStateNotifier(this.initialNodes) : super(_initState(initialNodes));

  static ArxmlTreeState _initState(List<ElementNode> rootNodes) {
    final flatMap = <int, ElementNode>{};
    int idCounter = 0;
    void buildFlatMap(ElementNode node, ElementNode? parent) {
      node.id = idCounter++;
      node.parent = parent;
      flatMap[node.id] = node;
      for (var child in node.children) {
        buildFlatMap(child, node);
      }
    }

    for (var node in rootNodes) {
      buildFlatMap(node, null);
    }

    final visibleNodes = _getVisibleNodes(rootNodes);
    return ArxmlTreeState(
        rootNodes: rootNodes,
        visibleNodes: UnmodifiableListView(visibleNodes),
        flatMap: flatMap);
  }

  static List<ElementNode> _getVisibleNodes(List<ElementNode> rootNodes) {
    final visible = <ElementNode>[];
    void traverse(ElementNode node) {
      visible.add(node);
      if (!node.isCollapsed) {
        for (var child in node.children) {
          traverse(child);
        }
      }
    }

    for (var node in rootNodes) {
      traverse(node);
    }
    return visible;
  }

  void toggleNodeCollapse(int nodeId) {
    final node = state.flatMap[nodeId];
    if (node == null) return;

    node.isCollapsed = !node.isCollapsed;
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
      contextMenuNodeId: state.contextMenuNodeId,
    );
  }

  void setContextMenuNode(int? nodeId) {
    state = state.copyWith(
        contextMenuNodeId: nodeId, clearContextMenu: nodeId == null);
  }

  void deleteNode(int nodeId) {
    final node = state.flatMap[nodeId];
    if (node == null) return;

    final parent = node.parent;
    if (parent != null) {
      parent.children.remove(node);
      // Re-initialize the state to reflect the change
      state = _initState(state.rootNodes);
    }
  }

  void editNodeValue(int nodeId, String newValue) {
    final node = state.flatMap[nodeId];
    if (node != null &&
        node.children.isNotEmpty &&
        node.children.first.children.isEmpty) {
      node.children.first.elementText = newValue;
      state = state.copyWith(); // Trigger a rebuild
    } else if (node != null && node.children.isEmpty) {
      node.elementText = newValue;
      state = state.copyWith();
    }
  }

  void renameNodeTag(int nodeId, String newTag) {
    final node = state.flatMap[nodeId];
    if (node == null) return;
    node.elementText = newTag;
    state = state.copyWith();
  }

  void addChildNode(int parentId, String elementName) {
    final parent = state.flatMap[parentId];
    if (parent == null) return;

    final newNode = ElementNode(
      elementText: elementName,
      depth: parent.depth + 1,
    );

    parent.children.add(newNode);
    state = _initState(
        state.rootNodes); // Re-init to rebuild flat map and visible nodes
  }

  void collapseAll() {
    for (var node in state.flatMap.values) {
      node.isCollapsed = true;
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
    );
  }

  void expandAll() {
    for (var node in state.flatMap.values) {
      node.isCollapsed = false;
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
    );
  }

  void expandUntilNode(int nodeId) {
    var node = state.flatMap[nodeId];
    if (node == null) return;

    var parent = node.parent;
    bool changed = false;
    while (parent != null) {
      if (parent.isCollapsed) {
        parent.isCollapsed = false;
        changed = true;
      }
      parent = parent.parent;
    }

    if (changed) {
      state = ArxmlTreeState(
        rootNodes: state.rootNodes,
        flatMap: state.flatMap,
        visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
      );
    }
  }

  // New: collapse/expand all descendants of a node (keep the node itself as-is)
  void collapseChildrenOf(int nodeId) {
    final node = state.flatMap[nodeId];
    if (node == null) return;

    void visit(ElementNode n) {
      for (final c in n.children) {
        c.isCollapsed = true;
        visit(c);
      }
    }

    visit(node);
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
    );
  }

  void expandChildrenOf(int nodeId) {
    final node = state.flatMap[nodeId];
    if (node == null) return;

    void visit(ElementNode n) {
      for (final c in n.children) {
        c.isCollapsed = false;
        visit(c);
      }
    }

    visit(node);
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
    );
  }
}

class FileTabState {
  final String path;
  final AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
      treeStateProvider;
  final XsdParser? xsdParser;
  final String? xsdPath;
  final bool isDirty;

  FileTabState({
    required this.path,
    required this.treeStateProvider,
    this.xsdParser,
    this.xsdPath,
    this.isDirty = false,
  });

  FileTabState copyWith({
    String? path,
    AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>?
        treeStateProvider,
    XsdParser? xsdParser,
    String? xsdPath,
    bool? isDirty,
  }) {
    return FileTabState(
      path: path ?? this.path,
      treeStateProvider: treeStateProvider ?? this.treeStateProvider,
      xsdParser: xsdParser ?? this.xsdParser,
      xsdPath: xsdPath ?? this.xsdPath,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
