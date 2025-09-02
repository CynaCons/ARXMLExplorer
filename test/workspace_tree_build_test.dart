import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/features/workspace/state/workspace_indexer.dart';
import 'package:arxml_explorer/features/workspace/service/workspace_models.dart';

void main() {
  group('WorkspaceIndexNotifier', () {
    test('builds hierarchical tree and sets statuses', () async {
      // Arrange: create a temporary folder with nested structure
      final tempDir = await Directory.systemTemp.createTemp('arxml_ws_');
      try {
        final dirA = Directory(
            '${tempDir.path}${Platform.pathSeparator}a${Platform.pathSeparator}b');
        final dirC = Directory('${tempDir.path}${Platform.pathSeparator}c');
        await dirA.create(recursive: true);
        await dirC.create(recursive: true);

        final okFile = File('${dirA.path}${Platform.pathSeparator}file1.arxml');
        final badFile =
            File('${dirC.path}${Platform.pathSeparator}invalid.arxml');

        await okFile.writeAsString(
            '<AUTOSAR><AR-PACKAGE><SHORT-NAME>A</SHORT-NAME></AR-PACKAGE></AUTOSAR>');
        await badFile
            .writeAsString('<AUTOSAR>'); // invalid XML to trigger error

        final notifier = WorkspaceIndexNotifier();

        // Act
        await notifier.indexFolder(tempDir.path);

        // Assert
        final state = notifier.state;
        expect(state.rootDir, tempDir.path);
        expect(state.tree, isNotNull);
        expect(state.fileStatus[okFile.path], IndexStatus.processed);
        expect(state.fileStatus[badFile.path], IndexStatus.error);
        // Root aggregate should be error due to invalid file
        expect(state.tree!.aggregateStatus, IndexStatus.error);
        // Expanded root directory
        expect(state.expandedDirs[tempDir.path], true);

        // Verify structure contains directories a and c
        final root = state.tree!;
        final names = root.children.map((e) => e.name).toSet();
        expect(names.contains('a'), true);
        expect(names.contains('c'), true);
        // Drill into a/b
        final dirAEntry = root.children.firstWhere(
            (e) => e.kind == WorkspaceNodeKind.folder && e.name == 'a');
        final dirBEntry = dirAEntry.children.firstWhere(
            (e) => e.kind == WorkspaceNodeKind.folder && e.name == 'b');
        final fileNames = dirBEntry.children
            .where((e) => e.kind == WorkspaceNodeKind.file)
            .map((e) => e.name)
            .toList();
        expect(fileNames, contains('file1.arxml'));
      } finally {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });
  });
}
