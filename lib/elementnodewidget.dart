import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/depth_indicator.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ElementNodeWidget extends ConsumerStatefulWidget {
  final ElementNode node;
  final XsdParser? xsdParser;
  final AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
      treeStateProvider;

  const ElementNodeWidget({
    required this.node,
    this.xsdParser,
    required this.treeStateProvider,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<ElementNodeWidget> createState() => _ElementNodeWidgetState();
}

class _ElementNodeWidgetState extends ConsumerState<ElementNodeWidget> {
  bool _isHovered = false;

  void _showContextMenu(BuildContext context, Offset tapPosition) {
    final notifier = ref.read(widget.treeStateProvider.notifier);
    notifier.setContextMenuNode(widget.node.id);

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final items = <PopupMenuEntry<String>>[];
    final isContainerWithText = widget.node.children.length == 1 &&
        widget.node.children.first.children.isEmpty;
    final isLeafValue = widget.node.children.isEmpty;

    if (isContainerWithText) {
      items.add(const PopupMenuItem<String>(
          value: 'edit_tag', child: Text('Rename Tag')));
    } else if (isLeafValue) {
      items.add(const PopupMenuItem<String>(
          value: 'edit_value', child: Text('Edit Value')));
    }

    items.addAll(const [
      PopupMenuItem<String>(value: 'add', child: Text('Add Child')),
      PopupMenuItem<String>(value: 'delete', child: Text('Delete Node')),
    ]);

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: items,
    ).then((value) {
      notifier.setContextMenuNode(null);
      if (value != null) {
        _handleMenuSelection(value);
      }
    });
  }

  bool _canEditValue(ElementNode node) {
    return node.children.isEmpty ||
        (node.children.length == 1 && node.children.first.children.isEmpty);
  }

  void _handleMenuSelection(String value) {
    final notifier = ref.read(widget.treeStateProvider.notifier);
    switch (value) {
      case 'edit_value':
        _showEditDialog(widget.node);
        break;
      case 'edit_tag':
        _showRenameTagDialog(widget.node);
        break;
      case 'add':
        _showAddChildDialog(widget.node);
        break;
      case 'delete':
        notifier.deleteNode(widget.node.id);
        break;
    }
  }

  void _showEditDialog(ElementNode node) {
    if (!_canEditValue(node)) return;
    final hasTextChild =
        node.children.length == 1 && node.children.first.children.isEmpty;
    final initialText = hasTextChild
        ? node.children.first.elementText
        : node.elementText; // prefill for leaf nodes
    final TextEditingController controller =
        TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Value'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                ref
                    .read(widget.treeStateProvider.notifier)
                    .editNodeValue(node.id, controller.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showRenameTagDialog(ElementNode node) {
    final controller = TextEditingController(text: node.elementText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New tag name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                ref
                    .read(widget.treeStateProvider.notifier)
                    .renameNodeTag(node.id, controller.text.trim());
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddChildDialog(ElementNode node) {
    String? selectedElement;
    final validChildren =
        widget.xsdParser?.getValidChildElements(node.elementText) ?? [];
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final canAdd =
                (selectedElement != null && selectedElement!.isNotEmpty) ||
                    customController.text.trim().isNotEmpty;
            return AlertDialog(
              title: const Text('Add Child Node'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Valid children for: ${node.elementText}'),
                  const SizedBox(height: 16),
                  if (validChildren.isNotEmpty)
                    DropdownButton<String>(
                      hint: const Text("Select a valid element"),
                      value: selectedElement,
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedElement = newValue;
                        });
                      },
                      items: validChildren
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    )
                  else
                    const Text('No valid child elements found in schema'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customController,
                    decoration: const InputDecoration(
                      labelText: 'Custom element name (optional)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Add'),
                  onPressed: canAdd
                      ? () {
                          final name =
                              selectedElement?.trim().isNotEmpty == true
                                  ? selectedElement!
                                  : customController.text.trim();
                          if (name.isNotEmpty) {
                            ref
                                .read(widget.treeStateProvider.notifier)
                                .addChildNode(node.id, name);
                          }
                          Navigator.of(context).pop();
                        }
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final treeState = ref.watch(widget.treeStateProvider);
    final isHighlighted = treeState.contextMenuNodeId == widget.node.id;
    final colorScheme = Theme.of(context).colorScheme;

    final highlightColor = colorScheme.primaryContainer; // context menu focus
    final hoverColor = colorScheme.secondaryContainer.withOpacity(0.18);
    final bgColor = isHighlighted
        ? highlightColor
        : (_isHovered ? hoverColor : null);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        color: bgColor,
        child: GestureDetector(
          onSecondaryTapDown: (details) =>
              _showContextMenu(context, details.globalPosition),
          child: ListTile(
            tileColor: Colors.transparent,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DepthIndicator(depth: widget.node.depth, isLastChild: false),
                if (widget.node.children.isNotEmpty)
                  IconButton(
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: AnimatedRotation(
                      turns: widget.node.isCollapsed ? 0.0 : 0.25,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.chevron_right),
                    ),
                    onPressed: () => ref
                        .read(widget.treeStateProvider.notifier)
                        .toggleNodeCollapse(widget.node.id),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
            title: Text(
                "${widget.node.elementText} ${widget.node.shortname} ${widget.node.definitionRef}".trim()),
            onTap: () {
              // Handle selection state via provider if needed
            },
          ),
        ),
      ),
    );
  }
}
