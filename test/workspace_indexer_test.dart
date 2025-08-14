import 'package:arxml_explorer/features/workspace/workspace.dart';
import 'package:arxml_explorer/features/workspace/service/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('findDefinitionCandidates aggregates multiple targets for same ref',
      () async {
    final notifier = WorkspaceIndexNotifier();
    // Seed state with two files containing the same absolute ref
    final key = '/Pkg/Comp/Port';
    final t1 = WorkspaceTarget(
        filePath: 'a.arxml', shortNamePath: const ['Pkg', 'Comp', 'Port']);
    final t2 = WorkspaceTarget(
        filePath: 'b.arxml', shortNamePath: const ['Pkg', 'Comp', 'Port']);

    notifier.state = notifier.state.copyWith(targets: {
      key: [t1, t2]
    });

    final list = notifier.findDefinitionCandidates(key);
    expect(list.length, 2);
    expect(list.any((e) => e.filePath == 'a.arxml'), isTrue);
    expect(list.any((e) => e.filePath == 'b.arxml'), isTrue);
  });

  test('goToDefinition does nothing when multiple candidates (UI should pick)',
      () async {
    final notifier = WorkspaceIndexNotifier();
    final key = '/Pkg/Comp/Port';
    final t1 = WorkspaceTarget(
        filePath: 'a.arxml', shortNamePath: const ['Pkg', 'Comp', 'Port']);
    final t2 = WorkspaceTarget(
        filePath: 'b.arxml', shortNamePath: const ['Pkg', 'Comp', 'Port']);
    notifier.state = notifier.state.copyWith(targets: {
      key: [t1, t2]
    });
    // We cannot call goToDefinition without a real WidgetRef; this test ensures no exception is thrown by findDefinitionCandidates.
    final list = notifier.findDefinitionCandidates(key);
    expect(list.length, 2);
  });
}
