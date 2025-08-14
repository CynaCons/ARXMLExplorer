import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import 'package:arxml_explorer/core/refs/ref_normalizer.dart';
import 'package:arxml_explorer/features/workspace/service/workspace_models.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import '../../../../workspace/workspace.dart'; // For WorkspaceIndexNotifier

class RefIndicator extends ConsumerWidget {
  final ElementNode node;
  final String? Function(ElementNode) computeBasePath;
  const RefIndicator(
      {super.key, required this.node, required this.computeBasePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (node.elementText != 'DEFINITION-REF' || node.children.isEmpty)
      return const SizedBox.shrink();
    final raw = node.children.first.elementText.trim();
    final idx = ref.watch(workspaceIndexProvider);
    final basePath = computeBasePath(node);
    final normalized = RefNormalizer.normalize(raw, basePath: basePath);
    final normalizedEcuc = RefNormalizer.normalizeEcuc(raw, basePath: basePath);
    final normalizedPort =
        RefNormalizer.normalizePortRef(raw, basePath: basePath);
    final showRefIndicator = raw.isNotEmpty &&
        (idx.hasTarget(normalized) ||
            idx.hasTarget(normalizedEcuc) ||
            idx.hasTarget(normalizedPort));
    String? refTooltip;
    String? key;
    if (idx.hasTarget(normalized))
      key = normalized;
    else if (idx.hasTarget(normalizedEcuc))
      key = normalizedEcuc;
    else if (idx.hasTarget(normalizedPort)) key = normalizedPort;
    if (key != null) {
      final list = idx.targets[key] ?? const [];
      refTooltip = list.isEmpty
          ? 'Reference target not found in workspace'
          : list.length == 1
              ? 'Go to definition — ${list.first.filePath}'
              : 'Multiple matches: ${list.length} files';
    } else {
      refTooltip = 'Reference target not found in workspace';
    }
    Future<void> goToDef() async {
      final notifier = ref.read(workspaceIndexProvider.notifier);
      final candidates =
          notifier.findDefinitionCandidates(raw, basePath: basePath);
      if (candidates.isEmpty) return;
      if (candidates.length == 1) {
        await notifier.goToDefinition(raw, ref, basePath: basePath);
        return;
      }
      final choice = await showDialog<WorkspaceTarget>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Multiple matches'),
          content: SizedBox(
            width: 520,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: candidates.length,
              itemBuilder: (_, i) {
                final c = candidates[i];
                final path = '/${c.shortNamePath.join('/')}';
                return ListTile(
                  dense: true,
                  title:
                      Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(c.filePath,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'))
          ],
        ),
      );
      if (choice != null) {
        await ref.read(fileTabsProvider.notifier).openFileAndNavigate(
            choice.filePath,
            shortNamePath: choice.shortNamePath);
      }
    }

    return Tooltip(
      message: refTooltip,
      child: IconButton(
        icon: Icon(showRefIndicator ? Icons.link : Icons.link_off,
            color: showRefIndicator ? Colors.green : Colors.grey),
        onPressed: showRefIndicator ? goToDef : null,
      ),
    );
  }
}
