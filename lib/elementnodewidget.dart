import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/depth_indicator.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/main.dart'
    show validationSchedulerProvider, fileTabsProvider; // access scheduler & tabs
import 'package:arxml_explorer/workspace_indexer.dart';

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

  // Helper to run live validation if enabled (debounced)
  Future<void> _maybeRunLiveValidation() async {
    if (!ref.read(liveValidationProvider)) return;
    ref.read(validationSchedulerProvider.notifier).schedule();
  }

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
      PopupMenuItem<String>(value: 'collapse_children', child: Text('Collapse children')),
      PopupMenuItem<String>(value: 'expand_children', child: Text('Expand children')),
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
      case 'collapse_children':
        notifier.collapseChildrenOf(widget.node.id);
        ref
            .read(fileTabsProvider.notifier)
            .markDirtyForTreeProvider(widget.treeStateProvider);
        break;
      case 'expand_children':
        notifier.expandChildrenOf(widget.node.id);
        break;
      case 'delete':
        notifier.deleteNode(widget.node.id);
        ref
            .read(fileTabsProvider.notifier)
            .markDirtyForTreeProvider(widget.treeStateProvider);
        _maybeRunLiveValidation();
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
                ref
                    .read(fileTabsProvider.notifier)
                    .markDirtyForTreeProvider(widget.treeStateProvider);
                Navigator.of(context).pop();
                _maybeRunLiveValidation();
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
                ref
                    .read(fileTabsProvider.notifier)
                    .markDirtyForTreeProvider(widget.treeStateProvider);
                Navigator.of(context).pop();
                _maybeRunLiveValidation();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddChildDialog(ElementNode node) {
    String? selectedElement;
    final validChildren = widget.xsdParser?.getValidChildElements(
            node.elementText,
            contextElementName: node.parent?.elementText) ??
        [];
    final customController = TextEditingController();
    String? errorText;

    // Remember last picked child per parent tag (session-only)
    selectedElement = _lastPickedByParent[node.elementText];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final canAdd =
                (selectedElement != null && selectedElement!.isNotEmpty) ||
                    customController.text.trim().isNotEmpty;
            errorText = canAdd ? null : 'Pick a valid element or enter a name';
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
                    decoration: InputDecoration(
                      labelText: 'Custom element name (optional)',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
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
                            _lastPickedByParent[node.elementText] = name;
                            ref
                                .read(widget.treeStateProvider.notifier)
                                .addChildNode(node.id, name);
                            ref
                                .read(fileTabsProvider.notifier)
                                .markDirtyForTreeProvider(widget.treeStateProvider);
                            _maybeRunLiveValidation();
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

  // Session memory for last picked child per parent tag
  static final Map<String, String> _lastPickedByParent = {};

  @override
  Widget build(BuildContext context) {
    final treeState = ref.watch(widget.treeStateProvider);
    final isHighlighted = treeState.contextMenuNodeId == widget.node.id;
    final colorScheme = Theme.of(context).colorScheme;

    final highlightColor = colorScheme.primaryContainer; // context menu focus
    final hoverColor = colorScheme.secondaryContainer.withOpacity(0.18);
    final bgColor =
        isHighlighted ? highlightColor : (_isHovered ? hoverColor : null);

    // Build a title that shows inline SHORT-NAME next to container nodes
    String titleText = widget.node.elementText;
    final hasShortNameChild = widget.node.children.isNotEmpty &&
        widget.node.children.first.elementText == 'SHORT-NAME' &&
        widget.node.children.first.children.isNotEmpty;
    if (hasShortNameChild) {
      final short = widget.node.children.first.children.first.elementText;
      titleText = '$titleText  •  $short';
    }

    // Reference indicator: show for DEFINITION-REF when the target exists in workspace indexer
    bool showRefIndicator = false;
    void Function()? goToDef;
    if (widget.node.elementText == 'DEFINITION-REF' &&
        widget.node.children.isNotEmpty) {
      final target = widget.node.children.first.elementText.trim();
      final idx = ref.watch(workspaceIndexProvider);
      showRefIndicator = target.isNotEmpty && idx.hasTarget(target);
      if (showRefIndicator) {
        goToDef = () => ref
            .read(workspaceIndexProvider.notifier)
            .goToDefinition(target, ref);
      }
    }

    // Validation issue badge placeholder (reads from provider; actual mapping of node->issue later)
    final issues = ref.watch(validationIssuesProvider);
    final hasIssue = issues.any((i) => i.path.contains(widget.node.elementText));

    // Prepare tooltip for ref indicator
    String? refTooltip;
    if (widget.node.elementText == 'DEFINITION-REF' &&
        widget.node.children.isNotEmpty) {
      final target = widget.node.children.first.elementText.trim();
      final idx = ref.watch(workspaceIndexProvider);
      if (idx.hasTarget(target)) {
        refTooltip = 'Go to definition — ' + (idx.targets[target]?.filePath ?? '');
      } else {
        refTooltip = 'Reference target not found in workspace';
      }
    }

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
          onLongPressStart: (details) =>
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
            title: Text(titleText.trim()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasIssue)
                  const Tooltip(
                    message: 'Validation issue',
                    child: Icon(Icons.error_outline, color: Colors.orange),
                  ),
                if (refTooltip != null)
                  Tooltip(
                    message: refTooltip,
                    child: IconButton(
                      icon: Icon(
                        showRefIndicator ? Icons.link : Icons.link_off,
                        color: showRefIndicator ? Colors.green : Colors.grey,
                      ),
                      onPressed: showRefIndicator ? goToDef : null,
                    ),
                  ),
              ],
            ),
            onTap: () {
              // Handle selection state via provider if needed
            },
          ),
        ),
      ),
    );
  }
}
