import 'package:arxml_explorer/core/refs/ref_normalizer.dart';

class WorkspaceTarget {
  final String filePath;
  final List<String> shortNamePath; // e.g., [Package, Component, Port]
  const WorkspaceTarget({required this.filePath, required this.shortNamePath});
}

enum IndexStatus { queued, processing, processed, error }

enum WorkspaceNodeKind { folder, file }

class WorkspaceTreeNode {
  final String name; // display name
  final String fullPath; // absolute path to folder or file
  final WorkspaceNodeKind kind;
  final List<WorkspaceTreeNode> children;
  final IndexStatus? fileStatus; // only for files
  final bool expanded; // only meaningful for folders
  final IndexStatus?
      aggregateHint; // optional precomputed aggregate for folders

  const WorkspaceTreeNode({
    required this.name,
    required this.fullPath,
    required this.kind,
    this.children = const [],
    this.fileStatus,
    this.expanded = false,
    this.aggregateHint,
  });

  WorkspaceTreeNode copyWith({
    String? name,
    String? fullPath,
    WorkspaceNodeKind? kind,
    List<WorkspaceTreeNode>? children,
    IndexStatus? fileStatus,
    bool? expanded,
    IndexStatus? aggregateHint,
  }) {
    return WorkspaceTreeNode(
      name: name ?? this.name,
      fullPath: fullPath ?? this.fullPath,
      kind: kind ?? this.kind,
      children: children ?? this.children,
      fileStatus: fileStatus ?? this.fileStatus,
      expanded: expanded ?? this.expanded,
      aggregateHint: aggregateHint ?? this.aggregateHint,
    );
  }

  // Aggregate directory status: error > processing > queued > processed
  IndexStatus? get aggregateStatus {
    if (kind == WorkspaceNodeKind.file) return fileStatus;
    // If an aggregate hint was provided (for lazily hydrated nodes), prefer it
    if (aggregateHint != null) return aggregateHint;
    if (children.isEmpty) return null;
    bool hasError = false,
        hasProcessing = false,
        hasQueued = false,
        hasProcessed = false;
    for (final c in children) {
      final st = c.aggregateStatus;
      switch (st) {
        case IndexStatus.error:
          hasError = true;
          break;
        case IndexStatus.processing:
          hasProcessing = true;
          break;
        case IndexStatus.queued:
          hasQueued = true;
          break;
        case IndexStatus.processed:
          hasProcessed = true;
          break;
        case null:
          break;
      }
      if (hasError) break;
    }
    if (hasError) return IndexStatus.error;
    if (hasProcessing) return IndexStatus.processing;
    if (hasQueued) return IndexStatus.queued;
    if (hasProcessed) return IndexStatus.processed;
    return null;
  }
}

class WorkspaceIndexState {
  final String? rootDir;
  final bool indexing;
  final DateTime? lastScan;
  final int filesIndexed;
  final int totalFilesToIndex;
  final Map<String, List<WorkspaceTarget>> targets; // ref -> candidates
  final Map<String, IndexStatus> fileStatus; // filePath -> status
  final WorkspaceTreeNode? tree; // hierarchical view of workspace
  final Map<String, bool> expandedDirs; // dirPath -> expanded

  const WorkspaceIndexState({
    this.rootDir,
    this.indexing = false,
    this.lastScan,
    this.filesIndexed = 0,
    this.totalFilesToIndex = 0,
    this.targets = const {},
    this.fileStatus = const {},
    this.tree,
    this.expandedDirs = const {},
  });

  double get progress =>
      totalFilesToIndex <= 0 ? 0 : filesIndexed / totalFilesToIndex;

  bool hasTarget(String ref) => (targets[ref] ?? const []).isNotEmpty;
  bool hasTargetNormalized(String ref, {String? basePath}) =>
      (targets[RefNormalizer.normalize(ref, basePath: basePath)] ?? const [])
          .isNotEmpty;

  WorkspaceIndexState copyWith({
    String? rootDir,
    bool? indexing,
    DateTime? lastScan,
    int? filesIndexed,
    int? totalFilesToIndex,
    Map<String, List<WorkspaceTarget>>? targets,
    Map<String, IndexStatus>? fileStatus,
    WorkspaceTreeNode? tree,
    Map<String, bool>? expandedDirs,
  }) {
    return WorkspaceIndexState(
      rootDir: rootDir ?? this.rootDir,
      indexing: indexing ?? this.indexing,
      lastScan: lastScan ?? this.lastScan,
      filesIndexed: filesIndexed ?? this.filesIndexed,
      totalFilesToIndex: totalFilesToIndex ?? this.totalFilesToIndex,
      targets: targets ?? this.targets,
      fileStatus: fileStatus ?? this.fileStatus,
      tree: tree ?? this.tree,
      expandedDirs: expandedDirs ?? this.expandedDirs,
    );
  }
}
