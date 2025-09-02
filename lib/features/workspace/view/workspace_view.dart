import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart' as fp;
import '../workspace.dart'; // For WorkspaceIndexNotifier
import 'package:arxml_explorer/features/workspace/service/workspace_models.dart';
import 'package:arxml_explorer/ui/home_shell.dart' show navRailIndexProvider;

class WorkspaceView extends ConsumerStatefulWidget {
  final void Function(String filePath) onOpenFile;
  const WorkspaceView({super.key, required this.onOpenFile});

  @override
  ConsumerState<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends ConsumerState<WorkspaceView> {
  bool _dragOver = false;
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final workspaceIndex = ref.watch(workspaceIndexProvider);
    final rootTree = workspaceIndex.tree;

    if (workspaceIndex.rootDir == null) {
      return Center(
        child: TextButton.icon(
          onPressed: () =>
              ref.read(workspaceIndexProvider.notifier).pickAndIndexWorkspace(),
          icon: const Icon(Icons.folder_open),
          label: const Text('Open Workspace'),
        ),
      );
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: (details) async {
        setState(() => _dragOver = false);
        final dropped =
            details.files.map((f) => f.path).whereType<String>().toList();
        if (dropped.isEmpty) return;

        bool isArxml(String path) {
          final ext = path.toLowerCase();
          return ext.endsWith('.arxml') || ext.endsWith('.xml');
        }

        Future<List<String>> collectArxml(String dir) async {
          final out = <String>[];
          try {
            final directory = Directory(dir);
            if (!directory.existsSync()) return out;
            await for (final ent
                in directory.list(recursive: true, followLinks: false)) {
              if (ent is File && isArxml(ent.path)) out.add(ent.path);
            }
          } catch (_) {}
          return out;
        }

        final dirs = <String>[];
        final filePaths = <String>[];
        for (final pth in dropped) {
          final t = FileSystemEntity.typeSync(pth, followLinks: false);
          if (t == FileSystemEntityType.directory) {
            dirs.add(pth);
          } else if (t == FileSystemEntityType.file) {
            if (isArxml(pth)) filePaths.add(pth);
          }
        }

        final idxNotifier = ref.read(workspaceIndexProvider.notifier);
        final root = ref.read(workspaceIndexProvider).rootDir;

        if (dirs.isNotEmpty) {
          if (root == null) {
            await idxNotifier.indexFolder(dirs.first);
            final extras = <String>[];
            for (int i = 1; i < dirs.length; i++) {
              extras.addAll(await collectArxml(dirs[i]));
            }
            extras.addAll(filePaths);
            if (extras.isNotEmpty) await idxNotifier.addFiles(extras);
          } else {
            final toAdd = <String>[];
            for (final d in dirs) {
              toAdd.addAll(await collectArxml(d));
            }
            toAdd.addAll(filePaths);
            if (toAdd.isNotEmpty) await idxNotifier.addFiles(toAdd);
          }
        } else {
          if (root == null) {
            final commonDir = p.dirname(filePaths.first);
            await idxNotifier.indexFolder(commonDir);
          } else {
            await idxNotifier.addFiles(filePaths);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Added ${dirs.length} folder(s), ${filePaths.length} file(s) to index'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (workspaceIndex.indexing)
                LinearProgressIndicator(
                  minHeight: 4,
                  value: workspaceIndex.progress == 0
                      ? null
                      : workspaceIndex.progress,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.folder, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${workspaceIndex.rootDir} — files: ${workspaceIndex.filesIndexed}${workspaceIndex.lastScan != null ? ' — last: ${workspaceIndex.lastScan}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Filter folders/files',
                          prefixIcon: Icon(Icons.search, size: 16),
                        ),
                        onChanged: (v) => setState(() => _filter = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(workspaceIndexProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final res = await fp.FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            type: fp.FileType.custom,
                            allowedExtensions: ['arxml', 'xml']);
                        if (res != null) {
                          final paths = res.files
                              .where((f) => f.path != null)
                              .map((f) => f.path!)
                              .toList();
                          await ref
                              .read(workspaceIndexProvider.notifier)
                              .addFiles(paths);
                        }
                      },
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add files'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: rootTree == null
                    ? const Center(
                        child: Text(
                            'No ARXML files indexed yet\nDrag and drop files/folders here',
                            textAlign: TextAlign.center),
                      )
                    : _WorkspaceTree(
                        root: rootTree,
                        filter: _filter,
                        fileStatus: workspaceIndex.fileStatus,
                        onOpenFile: (path) {
                          widget.onOpenFile(path);
                          try {
                            final container = ProviderScope.containerOf(context,
                                listen: false);
                            container
                                .read(navRailIndexProvider.notifier)
                                .state = 0;
                          } catch (_) {}
                        },
                      ),
              ),
            ],
          ),
          if (_dragOver)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.08),
                    border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.7), width: 2),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download,
                            size: 36, color: Colors.blueAccent),
                        SizedBox(height: 8),
                        Text('Drop files or folders to index',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueAccent)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceTree extends ConsumerWidget {
  final WorkspaceTreeNode root;
  final String filter;
  final Map<String, IndexStatus> fileStatus;
  final void Function(String path) onOpenFile;
  const _WorkspaceTree({
    required this.root,
    required this.filter,
    required this.fileStatus,
    required this.onOpenFile,
  });

  bool _matches(String name) {
    if (filter.isEmpty) return true;
    return name.toLowerCase().contains(filter.toLowerCase());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: _buildNodes(context, ref, root, 0),
    );
  }

  List<Widget> _buildNodes(
      BuildContext context, WidgetRef ref, WorkspaceTreeNode node, int depth) {
    final widgets = <Widget>[];
    bool includeNode = _matches(node.name);
    final childWidgets = <Widget>[];
    final isFolder = node.kind == WorkspaceNodeKind.folder;
    final shouldBuildChildren =
        // Always build children when filtering to allow matches within subtree
        (filter.isNotEmpty) ||
            // Or when the folder is expanded
            (isFolder && node.expanded);
    if (shouldBuildChildren) {
      for (final child in node.children) {
        childWidgets.addAll(_buildNodes(context, ref, child, depth + 1));
        if (!includeNode && childWidgets.isNotEmpty) includeNode = true;
      }
    }
    if (!includeNode) return const [];

    widgets.add(_WorkspaceRow(
      node: node,
      depth: depth,
      onToggle: () => ref
          .read(workspaceIndexProvider.notifier)
          .toggleDirExpanded(node.fullPath),
      onOpenFile: onOpenFile,
    ));
    if (isFolder && node.expanded) {
      widgets.addAll(childWidgets);
    }
    return widgets;
  }
}

class _WorkspaceRow extends StatelessWidget {
  final WorkspaceTreeNode node;
  final int depth;
  final VoidCallback onToggle;
  final void Function(String path) onOpenFile;
  const _WorkspaceRow({
    required this.node,
    required this.depth,
    required this.onToggle,
    required this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    final isDir = node.kind == WorkspaceNodeKind.folder;
    final status = node.aggregateStatus;
    IconData icon;
    Color color;
    if (isDir) {
      icon = node.expanded ? Icons.folder_open : Icons.folder;
      color = status == IndexStatus.error ? Colors.redAccent : Colors.blueGrey;
    } else {
      switch (status) {
        case IndexStatus.queued:
          icon = Icons.schedule;
          color = Colors.grey;
          break;
        case IndexStatus.processing:
          icon = Icons.hourglass_top;
          color = Colors.amber;
          break;
        case IndexStatus.processed:
          icon = Icons.description;
          color = Colors.green;
          break;
        case IndexStatus.error:
          icon = Icons.error_outline;
          color = Colors.redAccent;
          break;
        case null:
          icon = Icons.description;
          color = Colors.grey;
      }
    }

    // Compute file counts using fileStatus prefix to support lazy hydration
    int totalFilesPrefix(String dirPath) {
      final sep = Platform.pathSeparator;
      String norm(String p) => p.replaceAll('\\', sep).replaceAll('/', sep);
      final prefix =
          (norm(dirPath).endsWith(sep) ? norm(dirPath) : norm(dirPath) + sep);
      final container = ProviderScope.containerOf(context, listen: false);
      final statuses = container.read(workspaceIndexProvider).fileStatus;
      int sum = 0;
      for (final k in statuses.keys) {
        final kn = norm(k);
        if (kn.startsWith(prefix)) sum++;
      }
      return sum;
    }

    int processedFilesPrefix(String dirPath) {
      final sep = Platform.pathSeparator;
      String norm(String p) => p.replaceAll('\\', sep).replaceAll('/', sep);
      final prefix =
          (norm(dirPath).endsWith(sep) ? norm(dirPath) : norm(dirPath) + sep);
      final container = ProviderScope.containerOf(context, listen: false);
      final statuses = container.read(workspaceIndexProvider).fileStatus;
      int sum = 0;
      for (final e in statuses.entries) {
        final kn = norm(e.key);
        if (kn.startsWith(prefix) && e.value == IndexStatus.processed) sum++;
      }
      return sum;
    }

    int errorFilesPrefix(String dirPath) {
      final sep = Platform.pathSeparator;
      String norm(String p) => p.replaceAll('\\', sep).replaceAll('/', sep);
      final prefix =
          (norm(dirPath).endsWith(sep) ? norm(dirPath) : norm(dirPath) + sep);
      final container = ProviderScope.containerOf(context, listen: false);
      final statuses = container.read(workspaceIndexProvider).fileStatus;
      int sum = 0;
      for (final e in statuses.entries) {
        final kn = norm(e.key);
        if (kn.startsWith(prefix) && e.value == IndexStatus.error) sum++;
      }
      return sum;
    }

    Widget? trailing;
    String? tooltip;
    if (isDir) {
      final total = totalFilesPrefix(node.fullPath);
      final done = processedFilesPrefix(node.fullPath);
      final errs = errorFilesPrefix(node.fullPath);
      tooltip = errs > 0
          ? 'Processed $done / $total • Errors: $errs'
          : 'Processed $done / $total';
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errs > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  border: Border.all(color: Colors.redAccent, width: 1),
                ),
                child: Text('$errs',
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.35),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.4)),
            ),
            child: Text('$total',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    Future<void> _showMenuAt(Offset globalPos) async {
      final container = ProviderScope.containerOf(context, listen: false);
      final selected = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
            globalPos.dx, globalPos.dy, globalPos.dx, globalPos.dy),
        items: [
          if (isDir)
            const PopupMenuItem<String>(
              value: 'refresh',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.refresh),
                title: Text('Refresh Directory'),
              ),
            ),
          PopupMenuItem<String>(
            value: 'reveal',
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.folder_open),
              title: Text(
                  'Reveal in ${Platform.isWindows ? 'Explorer' : Platform.isMacOS ? 'Finder' : 'File Manager'}'),
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            value: 'remove',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.remove_circle_outline),
              title: Text('Remove From Index (coming soon)'),
            ),
          ),
        ],
      );
      switch (selected) {
        case 'refresh':
          // Refresh full index for now
          await container.read(workspaceIndexProvider.notifier).refresh();
          break;
        case 'reveal':
          try {
            if (Platform.isWindows) {
              if (isDir) {
                await Process.run('explorer', [node.fullPath]);
              } else {
                await Process.run('explorer', ['/select,', node.fullPath]);
              }
            } else if (Platform.isMacOS) {
              if (isDir) {
                await Process.run('open', [node.fullPath]);
              } else {
                await Process.run('open', ['-R', node.fullPath]);
              }
            } else {
              await Process.run('xdg-open', [node.fullPath]);
            }
          } catch (_) {}
          break;
      }
    }

    return InkWell(
      onTap: isDir ? onToggle : () => onOpenFile(node.fullPath),
      onDoubleTap: () => isDir ? onToggle() : onOpenFile(node.fullPath),
      onSecondaryTapDown: (details) => _showMenuAt(details.globalPosition),
      onLongPress: () {
        try {
          final rb = context.findRenderObject() as RenderBox?;
          final center = rb != null
              ? rb.localToGlobal(rb.size.center(Offset.zero))
              : Offset.zero;
          _showMenuAt(center);
        } catch (_) {
          _showMenuAt(Offset.zero);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(left: 8.0 + depth * 16.0),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: color),
          title: Text(
            node.name,
            overflow: TextOverflow.ellipsis,
            style: !isDir && status == IndexStatus.error
                ? const TextStyle(color: Colors.redAccent)
                : null,
          ),
          trailing: tooltip != null && trailing != null
              ? Tooltip(message: tooltip, child: trailing)
              : trailing,
        ),
      ),
    );
  }
}
