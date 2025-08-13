import 'package:arxml_explorer/ref_normalizer.dart';

class WorkspaceTarget {
  final String filePath;
  final List<String> shortNamePath; // e.g., [Package, Component, Port]
  const WorkspaceTarget({required this.filePath, required this.shortNamePath});
}

enum IndexStatus { queued, processing, processed, error }

class WorkspaceIndexState {
  final String? rootDir;
  final bool indexing;
  final DateTime? lastScan;
  final int filesIndexed;
  final int totalFilesToIndex;
  final Map<String, List<WorkspaceTarget>> targets; // ref -> candidates
  final Map<String, IndexStatus> fileStatus; // filePath -> status

  const WorkspaceIndexState({
    this.rootDir,
    this.indexing = false,
    this.lastScan,
    this.filesIndexed = 0,
    this.totalFilesToIndex = 0,
    this.targets = const {},
    this.fileStatus = const {},
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
  }) {
    return WorkspaceIndexState(
      rootDir: rootDir ?? this.rootDir,
      indexing: indexing ?? this.indexing,
      lastScan: lastScan ?? this.lastScan,
      filesIndexed: filesIndexed ?? this.filesIndexed,
      totalFilesToIndex: totalFilesToIndex ?? this.totalFilesToIndex,
      targets: targets ?? this.targets,
      fileStatus: fileStatus ?? this.fileStatus,
    );
  }
}
