import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'package:arxml_explorer/arxmlloader.dart';
import 'package:arxml_explorer/features/editor/view/widgets/search/custom_search_delegate.dart';
import 'dart:io';

void main() {
  group('Search Functionality', () {
    late ArxmlTreeState treeState;

    setUp(() async {
      final fileContent =
          await File('test/res/complex_nested.arxml').readAsString();
      final nodes = const ARXMLFileLoader().parseXmlContent(fileContent);
      final container = ProviderContainer();
      final notifier = container.read(arxmlTreeStateProvider(nodes).notifier);
      treeState = notifier.state;
    });

    test('Search delegate finds correct results for a value node', () {
      final delegate = CustomSearchDelegate(treeState);
      final results = delegate.performSearch('DeepValue');

      // The search finds 2 results: the VALUE element and the text content 'DeepValue'
      expect(results.length, 2);

      final elementTexts = results.map((node) => node.elementText).toList();
      expect(elementTexts, contains('VALUE'));
      expect(elementTexts, contains('DeepValue'));
    });

    test('Search delegate finds multiple results for container references', () {
      final delegate = CustomSearchDelegate(treeState);
      final results = delegate.performSearch('NestedContainerL2');

      // The search finds multiple occurrences (element names, text content, definition refs)
      expect(results.length, 6);

      final elementTexts = results.map((node) => node.elementText).toList();
      expect(elementTexts, contains('SHORT-NAME'));
      expect(elementTexts, contains('NestedContainerL2'));
      expect(elementTexts, contains('DEFINITION-REF'));
    });

    test('Search delegate performance is acceptable', () {
      final delegate = CustomSearchDelegate(treeState);

      // Test that search completes quickly
      final stopwatch = Stopwatch()..start();
      final results = delegate.performSearch('Container');
      stopwatch.stop();

      expect(results, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds,
          lessThan(1000)); // Should complete in under 1 second
    });
  });
}
