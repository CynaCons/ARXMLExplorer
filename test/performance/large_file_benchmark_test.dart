import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import 'package:arxml_explorer/core/validation/issues.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';

import '../support/arxml_generator.dart';

/// Repeatable performance baseline for large ARXML documents.
///
/// Run with:
///   flutter test test/performance/large_file_benchmark_test.dart --reporter expanded
///
/// This is a *measurement* harness, not a pass/fail gate — the numbers it prints
/// are the input to optimisation work. It carries a small number of loose
/// regression assertions so a catastrophic slowdown fails CI, but the thresholds
/// are deliberately generous: wall-clock assertions with tight bounds flake on
/// shared runners.
void main() {
  // Node counts to sweep. Real ECU extracts land in the 10k-200k range.
  const sizes = <int>[5000, 20000, 50000];

  String fmt(String label, int micros) =>
      '${label.padRight(38)} ${(micros / 1000).toStringAsFixed(1).padLeft(9)} ms';

  group('Large ARXML benchmarks', () {
    for (final target in sizes) {
      test('parse + tree build @ ~$target nodes', () {
        final xml = generateArxml(targetNodes: target);
        const loader = ARXMLFileLoader();

        final parseSw = Stopwatch()..start();
        final roots = loader.parseXmlContent(xml);
        parseSw.stop();

        final countSw = Stopwatch()..start();
        var nodeCount = 0;
        void walk(ElementNode n) {
          nodeCount++;
          for (final c in n.children) {
            walk(c);
          }
        }

        for (final r in roots) {
          walk(r);
        }
        countSw.stop();

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initSw = Stopwatch()..start();
        final treeProvider = arxmlTreeStateProvider(roots);
        final notifier = container.read(treeProvider.notifier);
        var state = container.read(treeProvider);
        initSw.stop();

        final expandSw = Stopwatch()..start();
        notifier.expandAll();
        expandSw.stop();
        state = container.read(treeProvider);
        final visibleExpanded = state.visibleNodes.length;

        final collapseSw = Stopwatch()..start();
        notifier.collapseAll();
        collapseSw.stop();

        // Cost of a single collapse toggle once everything is expanded — this is
        // what a user pays per chevron click.
        notifier.expandAll();
        final rootId = container.read(treeProvider).rootNodes.first.id;
        final toggleSw = Stopwatch()..start();
        notifier.toggleNodeCollapse(rootId);
        toggleSw.stop();

        // ignore: avoid_print
        print('''
--- ~$target nodes (actual $nodeCount, visible when expanded $visibleExpanded) ---
${fmt('xml parse -> ElementNode tree', parseSw.elapsedMicroseconds)}
${fmt('full tree walk (reference cost)', countSw.elapsedMicroseconds)}
${fmt('tree state init (ids + visible)', initSw.elapsedMicroseconds)}
${fmt('expandAll', expandSw.elapsedMicroseconds)}
${fmt('collapseAll', collapseSw.elapsedMicroseconds)}
${fmt('single toggle (root, all expanded)', toggleSw.elapsedMicroseconds)}''');

        expect(roots, isNotEmpty);
        expect(nodeCount, greaterThan(target ~/ 2));
        // Loose guards: catch an accidental O(n^2), not micro-regressions.
        expect(parseSw.elapsedMilliseconds, lessThan(30000));
        expect(expandSw.elapsedMilliseconds, lessThan(30000));
      }, timeout: const Timeout(Duration(minutes: 4)));
    }

    testWidgets('row build cost with and without validation issues',
        (tester) async {
      // A single screenful of rows is what actually gets built per frame.
      final xml = generateArxml(targetNodes: 20000);
      const loader = ARXMLFileLoader();
      final roots = loader.parseXmlContent(xml);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final treeProvider = arxmlTreeStateProvider(roots);
      container.read(treeProvider.notifier).expandAll();
      final visible = container.read(treeProvider).visibleNodes;

      Future<int> buildRows({required bool withIssues}) async {
        if (withIssues) {
          // One issue deep in the document. ValidationBadge scans descendants
          // per row, so a single issue is enough to expose the cost.
          final deep = visible.last;
          container.read(validationIssuesProvider.notifier).state = [
            ValidationIssue(path: '/x', message: 'synthetic', nodeId: deep.id),
          ];
        } else {
          container.read(validationIssuesProvider.notifier).state = const [];
        }

        const rowCount = 40; // ~one screenful
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 2000,
                  child: ListView.builder(
                    itemCount: rowCount,
                    itemBuilder: (_, i) => ElementNodeWidget(
                      node: visible[i],
                      treeStateProvider: treeProvider,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Force a rebuild of every row the way a selection change does, and time
        // it. This is the number that governs scroll smoothness.
        final sw = Stopwatch()..start();
        for (var i = 0; i < 5; i++) {
          container.read(treeProvider.notifier).setSelected(visible[i].id);
          await tester.pump();
        }
        sw.stop();
        return sw.elapsedMicroseconds ~/ 5;
      }

      // Warm up first: the first pump pays for JIT and cold caches, which
      // previously made whichever case ran second look artificially fast (it
      // reported a *negative* badge overhead).
      await buildRows(withIssues: false);
      await buildRows(withIssues: true);

      final clean = await buildRows(withIssues: false);
      final dirty = await buildRows(withIssues: true);
      final cleanAgain = await buildRows(withIssues: false);

      // ignore: avoid_print
      print('''
--- 40-row rebuild cost (per frame, budget 16.6 ms @ 60fps) ---
${fmt('no validation issues', clean)}
${fmt('no validation issues (repeat)', cleanAgain)}
${fmt('with 1 validation issue', dirty)}
${fmt('badge overhead', dirty - ((clean + cleanAgain) ~/ 2))}''');

      expect(clean, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
