import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/main.dart';
import 'package:arxml_explorer/arxml_tree_view_state.dart';

void main() {
  group('File Management Notifier', () {
    late ProviderContainer container;
    late FileTabsNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(fileTabsProvider.notifier);
    });

    test('Initial state is empty', () {
      expect(notifier.state, isEmpty);
    });

    // Note: Testing openNewFile directly is difficult due to FilePicker dependency.
    // We test the state changes by manually adding tabs.

    test('closeFile removes a tab and updates active index', () {
      // Add dummy tabs
      final tab1 = FileTabState(path: 'file1.arxml', treeStateProvider: arxmlTreeStateProvider([]));
      final tab2 = FileTabState(path: 'file2.arxml', treeStateProvider: arxmlTreeStateProvider([]));
      final tab3 = FileTabState(path: 'file3.arxml', treeStateProvider: arxmlTreeStateProvider([]));
      notifier.state = [tab1, tab2, tab3];
      container.read(activeTabIndexProvider.notifier).state = 2;

      // Close the middle tab
      notifier.closeFile(1);

      expect(notifier.state.length, 2);
      expect(notifier.state[0].path, 'file1.arxml');
      expect(notifier.state[1].path, 'file3.arxml');
      // Active index should shift down
      expect(container.read(activeTabIndexProvider), 1);
    });

     test('closeFile handles closing the last tab', () {
      final tab1 = FileTabState(path: 'file1.arxml', treeStateProvider: arxmlTreeStateProvider([]));
      notifier.state = [tab1];
      container.read(activeTabIndexProvider.notifier).state = 0;

      notifier.closeFile(0);

      expect(notifier.state, isEmpty);
      expect(container.read(activeTabIndexProvider), 0);
    });
  });
}
