import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/arxml_validator.dart';
import 'package:arxml_explorer/arxml_tree_view_state.dart';

class ValidationBadge extends ConsumerWidget {
  final ElementNode node;
  final AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
      treeStateProvider;
  const ValidationBadge(
      {super.key, required this.node, required this.treeStateProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allIssues = ref.watch(validationIssuesProvider);
    if (allIssues.isEmpty) return const SizedBox.shrink();
    final ids = <int>{};
    void gather(ElementNode n) {
      ids.add(n.id);
      for (final c in n.children) gather(c);
    }

    gather(node);
    final nodeIssues = allIssues
        .where((i) => i.nodeId != null && ids.contains(i.nodeId))
        .toList();
    if (nodeIssues.isEmpty) return const SizedBox.shrink();
    ValidationSeverity top = ValidationSeverity.info;
    for (final i in nodeIssues) {
      if (i.severity == ValidationSeverity.error) {
        top = ValidationSeverity.error;
        break;
      }
      if (i.severity == ValidationSeverity.warning)
        top = ValidationSeverity.warning;
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
                  style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        IconButton(
            icon: const Icon(Icons.arrow_circle_down, size: 18),
            tooltip: 'Go to issue',
            onPressed: () {
              ref.read(treeStateProvider.notifier).expandUntilNode(node.id);
            }),
      ]),
    );
  }
}
