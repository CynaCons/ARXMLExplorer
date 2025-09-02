import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import '../../../editor.dart'; // For ARXMLTreeViewState
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';
import 'package:arxml_explorer/features/editor/view/widgets/tree/depth_indicator.dart';
import 'element_node_actions.dart';
import 'ref_indicator.dart';
import 'validation_badge.dart';
import 'package:arxml_explorer/app_providers.dart';

class ElementNodeWidget extends ConsumerStatefulWidget {
  final ElementNode node;
  final XsdParser? xsdParser;
  final AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
      treeStateProvider;
  const ElementNodeWidget(
      {super.key,
      required this.node,
      this.xsdParser,
      required this.treeStateProvider});

  @override
  ConsumerState<ElementNodeWidget> createState() => _ElementNodeWidgetState();
}

class _ElementNodeWidgetState extends ConsumerState<ElementNodeWidget>
    with ElementNodeActions<ElementNodeWidget> {
  bool _isHovered = false;
  @override
  AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
      get treeStateProvider => widget.treeStateProvider;
  @override
  ElementNode get node => widget.node;
  @override
  XsdParser? get xsdParser => widget.xsdParser;

  void _showContextMenu(BuildContext context, Offset tapPosition) {
    final notifier = ref.read(treeStateProvider.notifier);
    notifier.setContextMenuNode(node.id);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final isContainerWithText =
        node.children.length == 1 && node.children.first.children.isEmpty;
    final isLeafValue = node.children.isEmpty;
    final isShortName = node.elementText == 'SHORT-NAME';
    final items = <PopupMenuEntry<String>>[];
    if (isContainerWithText) {
      items.add(
          const PopupMenuItem(value: 'edit_tag', child: Text('Rename Tag')));
    } else if (isLeafValue) {
      items.add(
          const PopupMenuItem(value: 'edit_value', child: Text('Edit Value')));
    }
    if (!isLeafValue && !isShortName) {
      items.add(const PopupMenuItem(
          value: 'convert_type', child: Text('Convert element type')));
    }
    if (isShortName) {
      items.add(const PopupMenuItem(
          value: 'safe_rename_short', child: Text('Safe Rename SHORT-NAME')));
    }
    items.addAll(const [
      PopupMenuItem(value: 'add', child: Text('Add Child')),
      PopupMenuItem(
          value: 'collapse_children', child: Text('Collapse children')),
      PopupMenuItem(value: 'expand_children', child: Text('Expand children')),
      PopupMenuItem(value: 'delete', child: Text('Delete Node')),
      PopupMenuItem(value: 'copy_path', child: Text('Copy path')),
    ]);
    showMenu(
            context: context,
            position: RelativeRect.fromRect(
                tapPosition & const Size(40, 40), Offset.zero & overlay.size),
            items: items)
        .then((value) {
      notifier.setContextMenuNode(null);
      if (value != null) {
        handleMenuSelection(context, value, ref);
      }
    });
  }

  String? _computeBasePath(ElementNode node) {
    final segs = <String>[];
    ElementNode? cur = node.parent;
    while (cur != null) {
      final hasShort = cur.children.isNotEmpty &&
          cur.children.first.elementText == 'SHORT-NAME' &&
          cur.children.first.children.isNotEmpty;
      if (hasShort)
        segs.add(cur.children.first.children.first.elementText.trim());
      cur = cur.parent;
    }
    if (segs.isEmpty) return null;
    return '/${segs.reversed.join('/')}';
  }

  @override
  Widget build(BuildContext context) {
    // Clear hover on any keyboard navigation tick to avoid dual highlight
    ref.listen<int>(keyboardNavTickProvider, (prev, next) {
      if (mounted && _isHovered) {
        setState(() => _isHovered = false);
      }
    });
    final treeState = ref.watch(treeStateProvider);
    final isSelected = treeState.selectedNodeId == node.id;
    final isContextMenuTarget = treeState.contextMenuNodeId == node.id;
    final colorScheme = Theme.of(context).colorScheme;
    final hasShortNameChild = node.children.isNotEmpty &&
        node.children.first.elementText == 'SHORT-NAME' &&
        node.children.first.children.isNotEmpty;
    final short = hasShortNameChild
        ? node.children.first.children.first.elementText
        : null;
    final titleText =
        short == null ? node.elementText : '${node.elementText}  •  $short';
    final highlightColor = colorScheme.primaryContainer;
    final hoverColor = colorScheme.secondaryContainer.withOpacity(0.18);
    final bgColor = isSelected
        ? highlightColor
        : (_isHovered
            ? hoverColor
            : (isContextMenuTarget ? highlightColor.withOpacity(0.6) : null));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        color: bgColor,
        child: GestureDetector(
          onSecondaryTapDown: (d) =>
              _showContextMenu(context, d.globalPosition),
          onLongPressStart: (d) => _showContextMenu(context, d.globalPosition),
          onTap: () =>
              ref.read(treeStateProvider.notifier).setSelected(node.id),
          child: ListTile(
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              DepthIndicator(depth: node.depth, isLastChild: false),
              if (node.children.isNotEmpty)
                IconButton(
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: AnimatedRotation(
                      turns: node.isCollapsed ? 0.0 : 0.25,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.chevron_right)),
                  onPressed: () => ref
                      .read(treeStateProvider.notifier)
                      .toggleNodeCollapse(node.id),
                )
              else
                const SizedBox(width: 40),
            ]),
            title: Text(titleText.trim()),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ValidationBadge(node: node, treeStateProvider: treeStateProvider),
              RefIndicator(node: node, computeBasePath: _computeBasePath),
            ]),
          ),
        ),
      ),
    );
  }
}
