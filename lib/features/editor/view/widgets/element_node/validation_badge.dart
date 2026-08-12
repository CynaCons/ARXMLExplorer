import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arxml_explorer/core/models/element_node.dart';
import 'package:arxml_explorer/core/validation/issues.dart';
import 'package:arxml_explorer/features/validation/state/node_issue_index.dart';
import '../../../editor.dart'; // For ARXMLTreeViewState

/// Issue indicator for one tree row.
///
/// Reads a precomputed index rather than walking its own subtree and scanning
/// every issue on each build — see [nodeIssueIndexProvider]. `select` keeps the
/// row from rebuilding when issues change elsewhere in the document.
class ValidationBadge extends ConsumerWidget {
  final ElementNode node;
  final AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
      treeStateProvider;
  const ValidationBadge(
      {super.key, required this.node, required this.treeStateProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      nodeIssueIndexProvider(treeStateProvider).select((m) => m[node.id]),
    );
    if (summary == null) return const SizedBox.shrink();

    final (icon, color) = switch (summary.severity) {
      ValidationSeverity.error => (Icons.error_outline, Colors.redAccent),
      ValidationSeverity.warning => (
          Icons.warning_amber_outlined,
          Colors.amber
        ),
      ValidationSeverity.info => (Icons.info_outline, Colors.blueAccent),
    };

    return Tooltip(
      message: summary.messages.join('\n'),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        if (summary.count > 1)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text('${summary.count}',
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        // Plain tappable icon, not IconButton: IconButton's ink/focus/
        // semantics machinery measured at 63 ms per scroll step per row.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              ref.read(treeStateProvider.notifier).expandUntilNode(node.id),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_circle_down, size: 18),
          ),
        ),
      ]),
    );
  }
}
