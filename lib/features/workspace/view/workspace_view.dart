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

  @override
  Widget build(BuildContext context) {
    final workspaceIndex = ref.watch(workspaceIndexProvider);
    final files = workspaceIndex.targets.values
        .expand((list) => list.map((t) => t.filePath))
        .toSet()
        .toList()
      ..sort();

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
              if (workspaceIndex.fileStatus.isNotEmpty)
                Expanded(
                  child: ListView(
                    children: workspaceIndex.fileStatus.entries.map((e) {
                      final st = e.value;
                      IconData icon;
                      Color color;
                      switch (st) {
                        case IndexStatus.queued:
                          icon = Icons.schedule;
                          color = Colors.grey;
                          break;
                        case IndexStatus.processing:
                          icon = Icons.hourglass_top;
                          color = Colors.amber;
                          break;
                        case IndexStatus.processed:
                          icon = Icons.check_circle_outline;
                          color = Colors.green;
                          break;
                        case IndexStatus.error:
                          icon = Icons.error_outline;
                          color = Colors.redAccent;
                          break;
                      }
                      return ListTile(
                        dense: true,
                        leading: Icon(icon, color: color),
                        title: Text(e.key.split(Platform.pathSeparator).last),
                        subtitle: Text(e.key, overflow: TextOverflow.ellipsis),
                        trailing: Text(st.name),
                      );
                    }).toList(),
                  ),
                )
              else
                const Divider(height: 1),
              Expanded(
                child: files.isEmpty
                    ? const Center(
                        child: Text(
                            'No ARXML files indexed yet\nDrag and drop files/folders here',
                            textAlign: TextAlign.center),
                      )
                    : ListView.builder(
                        itemCount: files.length,
                        itemBuilder: (context, i) {
                          final fp = files[i];
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap: () {
                              widget.onOpenFile(fp);
                              // After opening, request navigation to Editor view (index 0)
                              // Using navRailIndexProvider via context read if available
                              try {
                                final container = ProviderScope.containerOf(
                                    context,
                                    listen: false);
                                container
                                    .read(navRailIndexProvider.notifier)
                                    .state = 0;
                              } catch (_) {}
                            },
                            child: ListTile(
                              dense: true,
                              title:
                                  Text(fp.split(Platform.pathSeparator).last),
                              subtitle:
                                  Text(fp, overflow: TextOverflow.ellipsis),
                              leading: const Icon(Icons.description),
                              onTap: () => widget.onOpenFile(fp),
                            ),
                          );
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
