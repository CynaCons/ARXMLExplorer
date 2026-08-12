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
    // `select` rather than watching the whole state: a row only cares whether
    // *it* is selected. Watching ArxmlTreeState wholesale rebuilt every visible
    // row on every selection change — ~53 ms for a screenful of 40 rows against
    // a 16.6 ms frame budget, which is what made scrolling unusable.
    final isSelected =
        ref.watch(treeStateProvider.select((s) => s.selectedNodeId == node.id));
    final isContextMenuTarget = ref
        .watch(treeStateProvider.select((s) => s.contextMenuNodeId == node.id));
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

    // RepaintBoundary keeps a hover or selection repaint from dirtying the
    // whole viewport. ColoredBox + Row replace AnimatedContainer + ListTile:
    // the implicit animation allocated a ticker per row and ListTile is far
    // heavier than this layout needs.
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: ColoredBox(
          color: bgColor ?? Colors.transparent,
          child: GestureDetector(
            onSecondaryTapDown: (d) =>
                _showContextMenu(context, d.globalPosition),
            onLongPressStart: (d) =>
                _showContextMenu(context, d.globalPosition),
            onTap: () =>
                ref.read(treeStateProvider.notifier).setSelected(node.id),
            child: SizedBox(
              height: kRowHeight,
              child: Row(
                children: [
                  DepthIndicator(depth: node.depth, isLastChild: false),
                  if (node.children.isNotEmpty)
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                          width: 28, height: kRowHeight),
                      icon: Transform.rotate(
                        angle: node.isCollapsed ? 0.0 : 1.5707963,
                        child: const Icon(Icons.chevron_right),
                      ),
                      onPressed: () => ref
                          .read(treeStateProvider.notifier)
                          .toggleNodeCollapse(node.id),
                    )
                  else
                    const SizedBox(width: 28),
                  Expanded(
                    child: Text(
                      titleText.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ValidationBadge(
                      node: node, treeStateProvider: treeStateProvider),
                  RefIndicator(node: node, computeBasePath: _computeBasePath),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed row height.
///
/// Uniform rows let the list skip per-row layout measurement, which matters a
/// lot when the document has tens of thousands of them.
const double kRowHeight = 32;
