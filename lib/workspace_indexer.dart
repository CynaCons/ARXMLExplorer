import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart' as fp;
import 'main.dart' show fileTabsProvider; // for navigation via notifier
import 'ref_normalizer.dart';
import 'features/workspace/service/workspace_models.dart';

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
    state = state.copyWith(
      indexing: true,
      rootDir: rootDir,
      filesIndexed: 0,
      totalFilesToIndex: 0,
      fileStatus: {},
    );
    final targets = <String, List<WorkspaceTarget>>{};

    final dir = Directory(rootDir);
    if (!await dir.exists()) {
      state = state.copyWith(indexing: false);
      return;
    }

    // First pass: collect files to index
    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && _isArxml(entity.path)) {
        files.add(entity);
      }
    }

    // Initialize file statuses as queued
    final statuses = <String, IndexStatus>{
      for (final f in files) f.path: IndexStatus.queued
    };

    state = state.copyWith(
      totalFilesToIndex: files.length,
      fileStatus: statuses,
    );

    // Second pass: parse and extract targets, updating progress
    int processed = 0;
    for (final file in files) {
      try {
        // mark processing
        statuses[file.path] = IndexStatus.processing;
        state =
            state.copyWith(fileStatus: Map<String, IndexStatus>.from(statuses));

        final content = await file.readAsString();
        final doc = XmlDocument.parse(content);
        final fileTargets = _extractTargets(doc);
        for (final t in fileTargets) {
          final key = t.$1;
          final val = WorkspaceTarget(filePath: file.path, shortNamePath: t.$2);
          final list = targets.putIfAbsent(key, () => <WorkspaceTarget>[]);
          // avoid duplicate exact entries
          if (!list.any((e) =>
              e.filePath == val.filePath &&
              _pathsEqual(e.shortNamePath, val.shortNamePath))) {
            list.add(val);
          }
        }
        statuses[file.path] = IndexStatus.processed;
      } catch (_) {
        // ignore parse failures for indexing
        statuses[file.path] = IndexStatus.error;
      } finally {
        processed++;
        // Update progress occasionally to avoid excessive rebuilds
        if (processed % 5 == 0 || processed == files.length) {
          state = state.copyWith(
            filesIndexed: processed,
            fileStatus: Map<String, IndexStatus>.from(statuses),
          );
        }
      }
    }

    state = state.copyWith(
      indexing: false,
      lastScan: DateTime.now(),
      filesIndexed: processed,
      targets: targets,
      fileStatus: Map<String, IndexStatus>.from(statuses),
    );
  }

  // Add specific files to the index (e.g., from "Add files" in Workspace UI)
  Future<void> addFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    // ensure absolute, filter arxml
    final files =
        paths.map((pth) => File(pth)).where((f) => _isArxml(f.path)).toList();
    if (files.isEmpty) return;

    // Start/continue indexing session
    final statuses = Map<String, IndexStatus>.from(state.fileStatus);
    final targets = Map<String, List<WorkspaceTarget>>.from(state.targets);
    for (final f in files) {
      statuses[f.path] = IndexStatus.queued;
    }
    state = state.copyWith(
      indexing: true,
      totalFilesToIndex: files.length,
      filesIndexed: 0,
      fileStatus: statuses,
    );

    int processed = 0;
    for (final file in files) {
      try {
        statuses[file.path] = IndexStatus.processing;
        state =
            state.copyWith(fileStatus: Map<String, IndexStatus>.from(statuses));

        final content = await file.readAsString();
        final doc = XmlDocument.parse(content);
        final fileTargets = _extractTargets(doc);
        for (final t in fileTargets) {
          final key = t.$1;
          final val = WorkspaceTarget(filePath: file.path, shortNamePath: t.$2);
          final list = targets.putIfAbsent(key, () => <WorkspaceTarget>[]);
          if (!list.any((e) =>
              e.filePath == val.filePath &&
              _pathsEqual(e.shortNamePath, val.shortNamePath))) {
            list.add(val);
          }
        }
        statuses[file.path] = IndexStatus.processed;
      } catch (_) {
        statuses[file.path] = IndexStatus.error;
      } finally {
        processed++;
        if (processed % 5 == 0 || processed == files.length) {
          state = state.copyWith(
            filesIndexed: processed,
            fileStatus: Map<String, IndexStatus>.from(statuses),
          );
        }
      }
    }

    state = state.copyWith(
      indexing: false,
      lastScan: DateTime.now(),
      filesIndexed: processed,
      targets: targets,
      fileStatus: Map<String, IndexStatus>.from(statuses),
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

  // Return all candidates for a given reference (considering normalization variants)
  List<WorkspaceTarget> findDefinitionCandidates(String ref,
      {String? basePath}) {
    final normalized = RefNormalizer.normalize(ref, basePath: basePath);
    final normalizedEcuc = RefNormalizer.normalizeEcuc(ref, basePath: basePath);
    final normalizedPort =
        RefNormalizer.normalizePortRef(ref, basePath: basePath);

    final out = <WorkspaceTarget>[];
    void addAll(List<WorkspaceTarget>? items) {
      if (items == null) return;
      for (final t in items) {
        if (!out.any((e) =>
            e.filePath == t.filePath &&
            _pathsEqual(e.shortNamePath, t.shortNamePath))) {
          out.add(t);
        }
      }
    }

    addAll(state.targets[normalized]);
    addAll(state.targets[normalizedEcuc]);
    addAll(state.targets[normalizedPort]);
    return out;
  }

  static bool _pathsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> goToDefinition(String ref, WidgetRef refCtx,
      {String? basePath}) async {
    final candidates = findDefinitionCandidates(ref, basePath: basePath);
    if (candidates.isEmpty) return;
    if (candidates.length == 1) {
      final target = candidates.first;
      await refCtx.read(fileTabsProvider.notifier).openFileAndNavigate(
            target.filePath,
            shortNamePath: target.shortNamePath,
          );
    }
    // If multiple, caller/UI should handle disambiguation.
  }

  static bool _isArxml(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.arxml' || ext == '.xml';
  }

  // Extract absolute reference targets and their short-name paths
  static List<(String, List<String>)> _extractTargets(XmlDocument doc) {
    final results = <(String, List<String>)>[];

    void addAllKeys(String abs, List<String> nextPath) {
      // canonical absolute
      results.add((abs, nextPath));
      // alternative: ecuC and port forms
      final ecuc = RefNormalizer.normalizeEcuc(abs);
      if (ecuc != abs) results.add((ecuc, nextPath));
      final port = RefNormalizer.normalizePortRef(abs);
      if (port != abs) results.add((port, nextPath));
    }

    void walk(XmlElement el, List<String> shortPath) {
      // If this element has a SHORT-NAME child with text, capture it
      final sn = el.findElements('SHORT-NAME').firstOrNull?.innerText.trim();
      List<String> nextPath = shortPath;
      if (sn != null && sn.isNotEmpty) {
        nextPath = [...shortPath, sn];
        final abs = '/${nextPath.join('/')}';
        addAllKeys(abs, nextPath);
      }
      // Recurse into child elements
      for (final c in el.childElements) {
        walk(c, nextPath);
      }
    }

    for (final root in doc.childElements) {
      walk(root, const []);
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
