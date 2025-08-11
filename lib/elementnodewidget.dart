import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/depth_indicator.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/main.dart'
    show
        validationSchedulerProvider,
        fileTabsProvider; // access scheduler & tabs
import 'package:arxml_explorer/workspace_indexer.dart';
import 'package:arxml_explorer/ref_normalizer.dart';
import 'package:arxml_explorer/arxml_validator.dart';
import 'package:flutter/services.dart';

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
      PopupMenuItem<String>(
          value: 'collapse_children', child: Text('Collapse children')),
      PopupMenuItem<String>(
          value: 'expand_children', child: Text('Expand children')),
      PopupMenuItem<String>(value: 'delete', child: Text('Delete Node')),
    ]);
    // Add copy path option
    items.add(const PopupMenuItem<String>(
        value: 'copy_path', child: Text('Copy path')));

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
      case 'copy_path':
        final path = _buildElementPath(widget.node);
        Clipboard.setData(ClipboardData(text: path));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Path copied: $path'),
              duration: const Duration(seconds: 1)),
        );
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
                                .markDirtyForTreeProvider(
                                    widget.treeStateProvider);
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
      final raw = widget.node.children.first.elementText.trim();
      final idx = ref.watch(workspaceIndexProvider);
      final basePath = _computeBasePath(widget.node);
      final normalized = RefNormalizer.normalize(raw, basePath: basePath);
      final normalizedEcuc =
          RefNormalizer.normalizeEcuc(raw, basePath: basePath);
      final normalizedPort =
          RefNormalizer.normalizePortRef(raw, basePath: basePath);
      showRefIndicator = raw.isNotEmpty &&
          (idx.hasTarget(normalized) ||
              idx.hasTarget(normalizedEcuc) ||
              idx.hasTarget(normalizedPort));
      if (showRefIndicator) {
        void nav() async {
          final notifier = ref.read(workspaceIndexProvider.notifier);
          final candidates =
              notifier.findDefinitionCandidates(raw, basePath: basePath);
          if (candidates.isEmpty) return;
          if (candidates.length == 1) {
            await notifier.goToDefinition(raw, ref, basePath: basePath);
            return;
          }
          // Multiple candidates -> show disambiguation dialog
          if (!mounted) return;
          final choice = await showDialog<WorkspaceTarget>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Multiple matches'),
                content: SizedBox(
                  width: 520,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (context, i) {
                      final c = candidates[i];
                      final path = '/${c.shortNamePath.join('/')}';
                      return ListTile(
                        dense: true,
                        title: Text(path,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(c.filePath,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  )
                ],
              );
            },
          );
          if (choice != null) {
            await ref.read(fileTabsProvider.notifier).openFileAndNavigate(
                  choice.filePath,
                  shortNamePath: choice.shortNamePath,
                );
          }
        }

        goToDef = nav;
      }
    }

    // Prepare tooltip for ref indicator
    String? refTooltip;
    if (widget.node.elementText == 'DEFINITION-REF' &&
        widget.node.children.isNotEmpty) {
      final raw = widget.node.children.first.elementText.trim();
      final idx = ref.watch(workspaceIndexProvider);
      final basePath = _computeBasePath(widget.node);
      final normalized = RefNormalizer.normalize(raw, basePath: basePath);
      final normalizedEcuc =
          RefNormalizer.normalizeEcuc(raw, basePath: basePath);
      final normalizedPort =
          RefNormalizer.normalizePortRef(raw, basePath: basePath);
      String? key;
      if (idx.hasTarget(normalized))
        key = normalized;
      else if (idx.hasTarget(normalizedEcuc))
        key = normalizedEcuc;
      else if (idx.hasTarget(normalizedPort)) key = normalizedPort;
      if (key != null) {
        final list = idx.targets[key] ?? const <WorkspaceTarget>[];
        if (list.isEmpty) {
          refTooltip = 'Reference target not found in workspace';
        } else if (list.length == 1) {
          refTooltip = 'Go to definition — ${list.first.filePath}';
        } else {
          refTooltip = 'Multiple matches: ${list.length} files';
        }
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
                // Row-level issue indicator with severity color and tooltip (aggregated for subtree)
                Builder(builder: (_) {
                  final allIssues = ref.watch(validationIssuesProvider);
                  if (allIssues.isEmpty) return const SizedBox.shrink();
                  // Collect this node's subtree ids
                  final ids = <int>{};
                  void gather(ElementNode n) {
                    ids.add(n.id);
                    for (final c in n.children) gather(c);
                  }

                  gather(widget.node);
                  final nodeIssues = allIssues
                      .where((i) => i.nodeId != null && ids.contains(i.nodeId))
                      .toList();
                  if (nodeIssues.isEmpty) return const SizedBox.shrink();
                  // Pick highest severity icon/color
                  ValidationSeverity top = ValidationSeverity.info;
                  for (final i in nodeIssues) {
                    if (i.severity == ValidationSeverity.error) {
                      top = ValidationSeverity.error;
                      break;
                    }
                    if (i.severity == ValidationSeverity.warning) {
                      top = ValidationSeverity.warning;
                    }
                  }
                  final icon = top == ValidationSeverity.error
                      ? Icons.error_outline
                      : top == ValidationSeverity.warning
                          ? Icons.warning_amber_outlined
                          : Icons.info_outline;
                  final color = top == ValidationSeverity.error
                      ? Colors.redAccent
                      : top == ValidationSeverity.warning
                          ? Colors.amber
                          : Colors.blueAccent;
                  final tooltip = nodeIssues.map((i) => i.message).join('\n');
                  return Tooltip(
                    message: tooltip,
                    child: Row(children: [
                      Icon(icon, color: color),
                      if (nodeIssues.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text('${nodeIssues.length}',
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w600)),
                        ),
                      // Quick action: go to first issue under this subtree
                      IconButton(
                        icon: const Icon(Icons.arrow_circle_down, size: 18),
                        tooltip: 'Go to issue',
                        onPressed: () {
                          // Expand to make subtree visible; focus on current node for now
                          ref
                              .read(widget.treeStateProvider.notifier)
                              .expandUntilNode(widget.node.id);
                        },
                      )
                    ]),
                  );
                }),
                // Reference indicator
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

  // Build a base short-name path for relative references using the node's ancestry
  String? _computeBasePath(ElementNode node) {
    final segs = <String>[];
    ElementNode? cur = node.parent; // base is the container of DEFINITION-REF
    while (cur != null) {
      final hasShort = cur.children.isNotEmpty &&
          cur.children.first.elementText == 'SHORT-NAME' &&
          cur.children.first.children.isNotEmpty;
      if (hasShort) {
        segs.add(cur.children.first.children.first.elementText.trim());
      }
      cur = cur.parent;
    }
    if (segs.isEmpty) return null;
    return '/${segs.reversed.join('/')}';
  }

  String _buildElementPath(ElementNode node) {
    final segs = <String>[];
    ElementNode? cur = node;
    while (cur != null) {
      segs.add(cur.elementText);
      cur = cur.parent;
    }
    return '/' + segs.reversed.join('/');
  }
}
