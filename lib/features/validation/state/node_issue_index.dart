import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import 'package:arxml_explorer/core/validation/issues.dart';
import 'package:arxml_explorer/features/editor/state/arxml_tree_view_state.dart';

/// Aggregated validation state for one tree row.
class NodeIssueSummary {
  /// Highest severity found on this node or any descendant.
  final ValidationSeverity severity;

  /// How many issues that covers.
  final int count;

  /// Messages, for the row tooltip.
  final List<String> messages;

  const NodeIssueSummary({
    required this.severity,
    required this.count,
    required this.messages,
  });
}

typedef _TreeProvider
    = AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>;

/// Maps node id -> aggregated issue state for that node's whole subtree.
///
/// Previously each visible row computed this itself: it walked its entire
/// subtree collecting descendant ids, then linear-scanned every validation
/// issue. For a row near the root that means walking the whole document — per
/// row, per frame. With one synthetic issue in a 41k-node file that cost ~18 ms
/// on top of a 53 ms screenful rebuild.
///
/// This computes the same answer once, in a single post-order walk, and rows
/// just look themselves up.
final nodeIssueIndexProvider = Provider.autoDispose
    .family<Map<int, NodeIssueSummary>, _TreeProvider>((ref, treeProvider) {
  final issues = ref.watch(validationIssuesProvider);
  if (issues.isEmpty) return const <int, NodeIssueSummary>{};

  // Watch only rootNodes: it is the same List instance across copyWith, so
  // selection and hover changes do not invalidate this index.
  final roots = ref.watch(treeProvider.select((s) => s.rootNodes));

  // Direct issues per node id.
  final direct = <int, List<ValidationIssue>>{};
  for (final issue in issues) {
    final id = issue.nodeId;
    if (id == null) continue;
    (direct[id] ??= <ValidationIssue>[]).add(issue);
  }
  if (direct.isEmpty) return const <int, NodeIssueSummary>{};

  int rank(ValidationSeverity s) => switch (s) {
        ValidationSeverity.error => 3,
        ValidationSeverity.warning => 2,
        ValidationSeverity.info => 1,
      };

  final result = <int, NodeIssueSummary>{};

  /// Returns the subtree aggregate for [node], recording it on the way up.
  ({int rank, int count, List<String> messages}) visit(ElementNode node) {
    var topRank = 0;
    var count = 0;
    final messages = <String>[];

    final own = direct[node.id];
    if (own != null) {
      for (final i in own) {
        final r = rank(i.severity);
        if (r > topRank) topRank = r;
        messages.add(i.message);
      }
      count += own.length;
    }

    for (final child in node.children) {
      final sub = visit(child);
      if (sub.count == 0) continue;
      if (sub.rank > topRank) topRank = sub.rank;
      count += sub.count;
      messages.addAll(sub.messages);
    }

    if (count > 0) {
      result[node.id] = NodeIssueSummary(
        severity: switch (topRank) {
          3 => ValidationSeverity.error,
          2 => ValidationSeverity.warning,
          _ => ValidationSeverity.info,
        },
        count: count,
        // Cap the tooltip: a container near the root can aggregate thousands.
        messages: messages.length > 10
            ? [...messages.take(10), '... and ${messages.length - 10} more']
            : messages,
      );
    }
    return (rank: topRank, count: count, messages: messages);
  }

  for (final root in roots) {
    visit(root);
  }
  return result;
});
