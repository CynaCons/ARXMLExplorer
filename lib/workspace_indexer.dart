import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart' as fp;
import 'main.dart' show fileTabsProvider; // for navigation via notifier

class WorkspaceTarget {
  final String filePath;
  final List<String> shortNamePath; // e.g., [Package, Component, Port]
  const WorkspaceTarget({required this.filePath, required this.shortNamePath});
}

class WorkspaceIndexState {
  final String? rootDir;
  final bool indexing;
  final DateTime? lastScan;
  final int filesIndexed;
  final Map<String, WorkspaceTarget>
      targets; // key: absolute ref string like "/Pkg/Comp/Port"

  const WorkspaceIndexState({
    this.rootDir,
    this.indexing = false,
    this.lastScan,
    this.filesIndexed = 0,
    this.targets = const {},
  });

  bool hasTarget(String ref) => targets.containsKey(ref);

  WorkspaceIndexState copyWith({
    String? rootDir,
    bool? indexing,
    DateTime? lastScan,
    int? filesIndexed,
    Map<String, WorkspaceTarget>? targets,
  }) {
    return WorkspaceIndexState(
      rootDir: rootDir ?? this.rootDir,
      indexing: indexing ?? this.indexing,
      lastScan: lastScan ?? this.lastScan,
      filesIndexed: filesIndexed ?? this.filesIndexed,
      targets: targets ?? this.targets,
    );
  }
}

class WorkspaceIndexNotifier extends StateNotifier<WorkspaceIndexState> {
  WorkspaceIndexNotifier() : super(const WorkspaceIndexState());
  StreamSubscription<FileSystemEvent>? _watchSub;
  Timer? _debounce;

  Future<void> pickAndIndexWorkspace() async {
    final dir = await fp.FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    await indexFolder(dir);
    _startWatcher(dir);
  }

  Future<void> refresh() async {
    final dir = state.rootDir;
    if (dir == null) return;
    await indexFolder(dir);
  }

  Future<void> indexFolder(String rootDir) async {
    state = state.copyWith(indexing: true, rootDir: rootDir);
    final targets = <String, WorkspaceTarget>{};
    int count = 0;

    final dir = Directory(rootDir);
    if (!await dir.exists()) {
      state = state.copyWith(indexing: false);
      return;
    }

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && _isArxml(entity.path)) {
        try {
          final content = await entity.readAsString();
          final doc = XmlDocument.parse(content);
          final fileTargets = _extractTargets(doc);
          for (final t in fileTargets) {
            targets[t.$1] =
                WorkspaceTarget(filePath: entity.path, shortNamePath: t.$2);
          }
          count++;
        } catch (_) {
          // ignore parse failures for indexing
        }
      }
    }

    state = state.copyWith(
      indexing: false,
      lastScan: DateTime.now(),
      filesIndexed: count,
      targets: targets,
    );
  }

  void _startWatcher(String rootDir) {
    _watchSub?.cancel();
    final dir = Directory(rootDir);
    _watchSub = dir.watch(recursive: true).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 1), () {
        refresh();
      });
    });
  }

  Future<void> goToDefinition(String ref, WidgetRef refCtx) async {
    final target = state.targets[ref];
    if (target == null) return;
    // Ask tabs notifier to open file and navigate
    await refCtx.read(fileTabsProvider.notifier).openFileAndNavigate(
          target.filePath,
          shortNamePath: target.shortNamePath,
        );
  }

  static bool _isArxml(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.arxml' || ext == '.xml';
  }

  // Extract absolute reference targets and their short-name paths
  static List<(String, List<String>)> _extractTargets(XmlDocument doc) {
    final results = <(String, List<String>)>[];

    void walk(XmlElement el, List<String> shortPath) {
      // If this element has a SHORT-NAME child with text, capture it
      final sn = el.findElements('SHORT-NAME').firstOrNull?.innerText.trim();
      List<String> nextPath = shortPath;
      if (sn != null && sn.isNotEmpty) {
        nextPath = [...shortPath, sn];
        final abs = '/${nextPath.join('/')}';
        results.add((abs, nextPath));
      }
      // Recurse into child elements
      for (final c in el.childElements) {
        walk(c, nextPath);
      }
    }

    for (final root in doc.childElements) {
      if (root is XmlElement) {
        walk(root, const []);
      }
    }
    return results;
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

final workspaceIndexProvider =
    StateNotifierProvider<WorkspaceIndexNotifier, WorkspaceIndexState>((ref) {
  return WorkspaceIndexNotifier();
});

extension FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
