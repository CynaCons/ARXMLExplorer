import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import 'dart:collection';
import 'package:arxml_explorer/features/editor/state/commands/arxml_edit_command.dart';
import 'package:arxml_explorer/features/editor/state/commands/edit_value_command.dart';
import 'package:arxml_explorer/features/editor/state/commands/rename_tag_command.dart';
import 'package:arxml_explorer/features/editor/state/commands/add_child_command.dart';
import 'package:arxml_explorer/features/editor/state/commands/delete_node_command.dart';
import 'package:arxml_explorer/features/editor/state/commands/convert_type_command.dart';
import 'package:arxml_explorer/features/editor/state/commands/safe_rename_short_name_command.dart';

class ArxmlTreeState {
  final List<ElementNode> rootNodes;
  final UnmodifiableListView<ElementNode> visibleNodes;
  final Map<int, ElementNode> flatMap;
  final int? contextMenuNodeId;
  final int? selectedNodeId; // NEW: keyboard selection
  final int? pendingCenterNodeId; // NEW: request to center this node in view

  ArxmlTreeState({
    required this.rootNodes,
    required this.visibleNodes,
    required this.flatMap,
    this.contextMenuNodeId,
    this.selectedNodeId,
    this.pendingCenterNodeId,
  });

  ArxmlTreeState copyWith({
    int? contextMenuNodeId,
    bool clearContextMenu = false,
    int? selectedNodeId,
    bool clearSelection = false,
    int? pendingCenterNodeId,
    bool clearPendingCenter = false,
  }) {
    return ArxmlTreeState(
      rootNodes: rootNodes,
      visibleNodes: visibleNodes,
      flatMap: flatMap,
      contextMenuNodeId:
          clearContextMenu ? null : contextMenuNodeId ?? this.contextMenuNodeId,
      selectedNodeId:
          clearSelection ? null : (selectedNodeId ?? this.selectedNodeId),
      pendingCenterNodeId: clearPendingCenter
          ? null
          : (pendingCenterNodeId ?? this.pendingCenterNodeId),
    );
  }
}

final arxmlTreeStateProvider = StateNotifierProvider.autoDispose
    .family<ArxmlTreeStateNotifier, ArxmlTreeState, List<ElementNode>>(
        (ref, initialNodes) {
  // Keep alive to support programmatic tests manipulating the tree without UI listeners
  ref.keepAlive();
  return ArxmlTreeStateNotifier(initialNodes);
});

class ArxmlTreeStateNotifier extends StateNotifier<ArxmlTreeState> {
  final List<ElementNode> initialNodes;
  ArxmlTreeStateNotifier(this.initialNodes) : super(_initState(initialNodes));

  static ArxmlTreeState _initState(List<ElementNode> rootNodes) {
    // ignore: avoid_print
    print('[tree] initState start rootCount=' + rootNodes.length.toString());
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
    // ignore: avoid_print
    print('[tree] initState visible=' + visibleNodes.length.toString());
    return ArxmlTreeState(
        rootNodes: rootNodes,
        visibleNodes: UnmodifiableListView(visibleNodes),
        flatMap: flatMap,
        selectedNodeId: visibleNodes.isNotEmpty ? visibleNodes.first.id : null,
        pendingCenterNodeId: null);
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
    final newVisible = UnmodifiableListView(_getVisibleNodes(state.rootNodes));
    // preserve selection if still visible else choose closest
    int? sel = state.selectedNodeId;
    if (sel != null && !newVisible.any((n) => n.id == sel)) {
      // find first ancestor visible
      sel = newVisible.isNotEmpty ? newVisible.first.id : null;
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: newVisible,
      contextMenuNodeId: state.contextMenuNodeId,
      selectedNodeId: sel,
      pendingCenterNodeId: state.pendingCenterNodeId,
    );
  }

  void setContextMenuNode(int? nodeId) {
    state = state.copyWith(
        contextMenuNodeId: nodeId, clearContextMenu: nodeId == null);
  }

  final List<ArxmlEditCommand> _undoStack = [];
  final List<ArxmlEditCommand> _redoStack = [];

  void _pushCommand(ArxmlEditCommand cmd) {
    cmd.apply();
    _undoStack.add(cmd);
    _redoStack.clear();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  bool _isStructural(ArxmlEditCommand cmd) => cmd.isStructural();

  void undo() {
    if (_undoStack.isEmpty) return;
    final cmd = _undoStack.removeLast();
    cmd.revert();
    _redoStack.add(cmd);
    if (_isStructural(cmd)) {
      _rebuildFlatMap();
    } else {
      state = state.copyWith();
    }
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final cmd = _redoStack.removeLast();
    cmd.apply();
    _undoStack.add(cmd);
    if (_isStructural(cmd)) {
      _rebuildFlatMap();
    } else {
      state = state.copyWith();
    }
  }

  // Modified editing operations to use commands
  void editNodeValue(int nodeId, String newValue) {
    final node = state.flatMap[nodeId];
    if (node == null) return;
    final oldValue =
        node.children.isNotEmpty && node.children.first.children.isEmpty
            ? node.children.first.elementText
            : node.elementText;
    if (oldValue == newValue) return;
    _pushCommand(EditValueCommand(node, oldValue, newValue));
    state = state.copyWith();
  }

  void renameNodeTag(int nodeId, String newTag) {
    final node = state.flatMap[nodeId];
    if (node == null) return;
    final oldTag = node.elementText;
    if (oldTag == newTag) return;
    _pushCommand(RenameTagCommand(node, oldTag, newTag));
    state = state.copyWith();
  }

  void addChildNode(int parentId, String elementName) {
    final parent = state.flatMap[parentId];
    if (parent == null) return;
    final newNode = ElementNode(
        elementText: elementName, depth: parent.depth + 1, children: []);
    final wasCollapsed = parent.isCollapsed;
    _pushCommand(AddChildCommand(parent, newNode));
    // Expand parent if it was collapsed so the new child becomes visible
    if (wasCollapsed) {
      parent.isCollapsed = false;
    }
    _rebuildFlatMap();
    // After rebuild, select the newly added node
    if (newNode.id != -1) {
      // select and request centering in UI
      state = state.copyWith(
        selectedNodeId: newNode.id,
        pendingCenterNodeId: newNode.id,
      );
    }
  }

  void deleteNode(int nodeId) {
    final node = state.flatMap[nodeId];
    if (node == null) return;
    final parent = node.parent;
    if (parent == null) return;
    final idx = parent.children.indexOf(node);
    _pushCommand(DeleteNodeCommand(parent, node, idx));
    _rebuildFlatMap();
  }

  // New: convert element type with optional XSD-based child pruning
  void convertNodeType(int nodeId, String newType, {XsdParser? parser}) {
    final node = state.flatMap[nodeId];
    if (node == null) return;
    final oldTag = node.elementText;
    if (oldTag == newType) return;
    // Determine allowed children for newType relative to parent context
    final allowed = parser?.getValidChildElements(newType,
            contextElementName: node.parent?.elementText) ??
        const <String>[];
    final preserved = <ElementNode>[];
    final removed = <ElementNode>[];
    for (final c in node.children) {
      if (c.elementText == 'SHORT-NAME' || allowed.contains(c.elementText)) {
        preserved.add(c);
      } else {
        removed.add(c);
      }
    }
    node.children = preserved;
    final cmd = ConvertTypeCommand(node, oldTag, newType, removed);
    _pushCommand(cmd);
    _rebuildFlatMap();
  }

  // Compute canonical short-name path for a SHORT-NAME node's parent container
  List<String> _shortNamePathForShortNameNode(ElementNode shortNameNode) {
    final segments = <String>[];
    ElementNode? container =
        shortNameNode.parent; // container whose short-name this is
    while (container != null) {
      final snChild = container.children.isNotEmpty &&
              container.children.first.elementText == 'SHORT-NAME' &&
              container.children.first.children.isNotEmpty
          ? container.children.first.children.first.elementText.trim()
          : null;
      if (snChild != null && snChild.isNotEmpty) {
        segments.add(snChild);
      }
      container = container.parent;
    }
    return segments.reversed.toList();
  }

  void safeRenameShortName(int nodeId, String newShortName) {
    final snNode = state.flatMap[nodeId];
    if (snNode == null) return;
    if (snNode.elementText != 'SHORT-NAME') return;
    if (snNode.children.isEmpty) return;
    final oldValue = snNode.children.first.elementText.trim();
    if (oldValue == newShortName) return;
    if (isShortNameConflict(nodeId, newShortName)) {
      return; // conflict detected, do not apply
    }
    final pathSegments = _shortNamePathForShortNameNode(snNode);
    if (pathSegments.isEmpty) return; // root short-name unsupported
    final oldPath = '/${[...pathSegments].join('/')}';
    final newPath = '/${[
      ...pathSegments.sublist(0, pathSegments.length - 1),
      newShortName
    ].join('/')}';
    final updatedRefNodes = <ElementNode>[];
    final oldRefValues = <String>[];
    final newRefValues = <String>[];
    for (final entry in state.flatMap.values) {
      if (entry.elementText == 'DEFINITION-REF' &&
          entry.children.isNotEmpty &&
          entry.children.first.elementText.trim() == oldPath) {
        updatedRefNodes.add(entry);
        oldRefValues.add(entry.children.first.elementText);
        newRefValues.add(newPath);
      }
    }
    final cmd = SafeRenameShortNameCommand(snNode, oldValue, newShortName,
        updatedRefNodes, oldRefValues, newRefValues);
    _pushCommand(cmd);
    state = state.copyWith();
  }

  bool isShortNameConflict(int nodeId, String proposed) {
    final snNode = state.flatMap[nodeId];
    if (snNode == null || snNode.elementText != 'SHORT-NAME') return false;
    if (snNode.children.isEmpty) return false;
    final container = snNode.parent; // element that owns this SHORT-NAME
    if (container == null) return false;
    final parentOfContainers = container.parent; // siblings share this parent
    if (parentOfContainers == null) return false;
    for (final sibling in parentOfContainers.children) {
      if (sibling == container) continue;
      if (sibling.children.isNotEmpty &&
          sibling.children.first.elementText == 'SHORT-NAME' &&
          sibling.children.first.children.isNotEmpty) {
        final val = sibling.children.first.children.first.elementText.trim();
        if (val == proposed) return true;
      }
    }
    return false;
  }

  void _rebuildFlatMap() {
    // rebuild flatMap & visible
    final flat = <int, ElementNode>{};
    int id = 0;
    void walk(ElementNode n) {
      n.id = id++;
      flat[n.id] = n;
      for (final c in n.children) walk(c);
    }

    for (final r in state.rootNodes) walk(r);
    final visible = UnmodifiableListView(_getVisibleNodes(state.rootNodes));
    int? sel = state.selectedNodeId;
    if (sel != null && !visible.any((n) => n.id == sel)) {
      sel = visible.isNotEmpty ? visible.first.id : null;
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: flat,
      visibleNodes: visible,
      contextMenuNodeId: state.contextMenuNodeId,
      selectedNodeId: sel,
      pendingCenterNodeId: state.pendingCenterNodeId,
    );
  }

  // Navigation helpers (moved from extension)
  void collapseChildrenOf(int nodeId) {
    final node = state.flatMap[nodeId];
    if (node == null) return;
    for (final c in node.children) {
      c.isCollapsed = true;
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
      contextMenuNodeId: state.contextMenuNodeId,
      pendingCenterNodeId: state.pendingCenterNodeId,
    );
  }

  void expandChildrenOf(int nodeId) {
    final node = state.flatMap[nodeId];
    if (node == null) return;
    for (final c in node.children) {
      c.isCollapsed = false;
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
      contextMenuNodeId: state.contextMenuNodeId,
      pendingCenterNodeId: state.pendingCenterNodeId,
    );
  }

  // Convenience: collapse all nodes so only roots are visible
  void collapseAll() {
    // ignore: avoid_print
    print('[tree] collapseAll');
    void walk(ElementNode n) {
      if (n.children.isNotEmpty) {
        // Collapse this node and all descendants
        n.isCollapsed = true;
        for (final c in n.children) {
          walk(c);
        }
      }
    }

    for (final r in state.rootNodes) {
      walk(r);
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
      contextMenuNodeId: state.contextMenuNodeId,
      pendingCenterNodeId: state.pendingCenterNodeId,
    );
  }

  // Convenience: expand all nodes so all are visible
  void expandAll() {
    // ignore: avoid_print
    print('[tree] expandAll');
    void walk(ElementNode n) {
      if (n.children.isNotEmpty) {
        n.isCollapsed = false;
        for (final c in n.children) {
          walk(c);
        }
      }
    }

    for (final r in state.rootNodes) {
      walk(r);
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
      contextMenuNodeId: state.contextMenuNodeId,
      pendingCenterNodeId: state.pendingCenterNodeId,
    );
  }

  void expandUntilNode(int nodeId) {
    final target = state.flatMap[nodeId];
    if (target == null) return;
    ElementNode? cur = target.parent;
    while (cur != null) {
      cur.isCollapsed = false;
      cur = cur.parent;
    }
    state = ArxmlTreeState(
      rootNodes: state.rootNodes,
      flatMap: state.flatMap,
      visibleNodes: UnmodifiableListView(_getVisibleNodes(state.rootNodes)),
      contextMenuNodeId: state.contextMenuNodeId,
    );
  }

  // NEW: Selection helpers
  void setSelected(int? nodeId) {
    if (nodeId != null && !state.visibleNodes.any((n) => n.id == nodeId)) {
      return; // ignore invisible selection
    }
    state = state.copyWith(selectedNodeId: nodeId);
  }

  void selectFirst() {
    if (state.visibleNodes.isEmpty) return;
    setSelected(state.visibleNodes.first.id);
  }

  void selectLast() {
    if (state.visibleNodes.isEmpty) return;
    setSelected(state.visibleNodes.last.id);
  }

  void selectUp() {
    if (state.selectedNodeId == null) {
      selectFirst();
      return;
    }
    final idx =
        state.visibleNodes.indexWhere((n) => n.id == state.selectedNodeId);
    if (idx > 0) setSelected(state.visibleNodes[idx - 1].id);
  }

  void selectDown() {
    if (state.selectedNodeId == null) {
      selectFirst();
      return;
    }
    final idx =
        state.visibleNodes.indexWhere((n) => n.id == state.selectedNodeId);
    if (idx >= 0 && idx < state.visibleNodes.length - 1) {
      setSelected(state.visibleNodes[idx + 1].id);
    }
  }

  void collapseOrGoParent() {
    if (state.selectedNodeId == null) return;
    final node = state.flatMap[state.selectedNodeId];
    if (node == null) return;
    if (!node.isCollapsed && node.children.isNotEmpty) {
      toggleNodeCollapse(node.id);
    } else if (node.parent != null) {
      setSelected(node.parent!.id);
    }
  }

  void expandOrGoChild() {
    if (state.selectedNodeId == null) return;
    final node = state.flatMap[state.selectedNodeId];
    if (node == null) return;
    if (node.isCollapsed && node.children.isNotEmpty) {
      toggleNodeCollapse(node.id);
    } else if (node.children.isNotEmpty) {
      setSelected(node.children.first.id);
    }
  }

  void pageUp({int pageSize = 20}) {
    if (state.selectedNodeId == null) {
      selectFirst();
      return;
    }
    final idx =
        state.visibleNodes.indexWhere((n) => n.id == state.selectedNodeId);
    final next = (idx - pageSize).clamp(0, state.visibleNodes.length - 1);
    setSelected(state.visibleNodes[next].id);
  }

  void pageDown({int pageSize = 20}) {
    if (state.selectedNodeId == null) {
      selectFirst();
      return;
    }
    final idx =
        state.visibleNodes.indexWhere((n) => n.id == state.selectedNodeId);
    final next = (idx + pageSize).clamp(0, state.visibleNodes.length - 1);
    setSelected(state.visibleNodes[next].id);
  }

  void toggleExpandOrEdit(void Function(ElementNode) onEditValue) {
    if (state.selectedNodeId == null) return;
    final node = state.flatMap[state.selectedNodeId];
    if (node == null) return;
    if (node.children.isEmpty) {
      onEditValue(node);
    } else {
      toggleNodeCollapse(node.id);
    }
  }

  void ensureSelectionVisible(void Function(int index) onNeedScroll) {
    if (state.selectedNodeId == null) return;
    final idx =
        state.visibleNodes.indexWhere((n) => n.id == state.selectedNodeId);
    if (idx == -1) return;
    onNeedScroll(idx);
  }

  // NEW: Ensure a particular node is centered in the viewport on next frame
  void ensureNodeCentered(int nodeId) {
    final node = state.flatMap[nodeId];
    if (node == null) return;
    // Expand ancestors so it's visible, then request centering
    expandUntilNode(nodeId);
    state = state.copyWith(
      selectedNodeId: nodeId,
      pendingCenterNodeId: nodeId,
    );
  }

  // Clear pending center request (UI should call after scrolling)
  void clearPendingCenter() {
    if (state.pendingCenterNodeId == null) return;
    state = state.copyWith(clearPendingCenter: true);
  }
}

class FileTabState {
  final String path;
  final AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
      treeStateProvider;
  final XsdParser? xsdParser;
  final String? xsdPath;
  final String?
      xsdSource; // catalog:basename|catalog:version|catalog:nearest|bundled|workspace|direct|manual|fallback
  final bool isDirty;
  final String? lastSavedSnapshot; // serialized XML snapshot
  FileTabState({
    required this.path,
    required this.treeStateProvider,
    this.xsdParser,
    this.xsdPath,
    this.xsdSource,
    this.isDirty = false,
    this.lastSavedSnapshot,
  });
  FileTabState copyWith({
    String? path,
    AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>?
        treeStateProvider,
    XsdParser? xsdParser,
    String? xsdPath,
    String? xsdSource,
    bool? isDirty,
    String? lastSavedSnapshot,
  }) {
    return FileTabState(
      path: path ?? this.path,
      treeStateProvider: treeStateProvider ?? this.treeStateProvider,
      xsdParser: xsdParser ?? this.xsdParser,
      xsdPath: xsdPath ?? this.xsdPath,
      xsdSource: xsdSource ?? this.xsdSource,
      isDirty: isDirty ?? this.isDirty,
      lastSavedSnapshot: lastSavedSnapshot ?? this.lastSavedSnapshot,
    );
  }
}
