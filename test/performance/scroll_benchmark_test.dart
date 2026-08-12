import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';
import 'package:arxml_explorer/features/editor/view/widgets/tree/tree_scroll_controller.dart';

import '../support/arxml_generator.dart';

/// Scroll and scrollbar performance.
///
/// This file exists because the previous benchmark only measured *row rebuild*
/// cost. That number improved 12x while scrolling stayed unusable and dragging
/// the scrollbar froze the app — the harness was blind to exactly the thing
/// that was broken.
///
/// Measured with ScrollablePositionedList, which this replaced:
///   n=10,000  jump = 16,637 ms
///   n=50,000  never completed
/// With ListView + itemExtent: 24 ms and 39 ms respectively.
void main() {
  const sizes = <int>[10000, 50000];

  /// Generous ceiling. A jump is O(1) now; this only has to catch a return to
  /// the O(n) behaviour, so it will not flake on a loaded CI runner.
  const maxJumpMs = 500;

  group('Editor scroll performance', () {
    for (final target in sizes) {
      testWidgets('scroll + scrollbar jumps @ ~$target nodes', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final roots = const ARXMLFileLoader()
            .parseXmlContent(generateArxml(targetNodes: target));

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final treeProvider = arxmlTreeStateProvider(roots);
        container.read(treeProvider.notifier).expandAll();
        final visible = container.read(treeProvider).visibleNodes;

        final scroll = TreeScrollController();
        addTearDown(scroll.dispose);

        final layoutSw = Stopwatch()..start();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Scrollbar(
                  controller: scroll.scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: scroll.scrollController,
                    itemExtent: kRowHeight,
                    itemCount: visible.length,
                    itemBuilder: (_, i) => ElementNodeWidget(
                      key: ValueKey<int>(visible[i].id),
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
        layoutSw.stop();

        final position = scroll.scrollController.position;

        // The scroll extent must be exact, not estimated. This is what makes a
        // real scrollbar possible — SPL could not provide it.
        final expectedExtent =
            visible.length * kRowHeight - position.viewportDimension;
        expect(position.maxScrollExtent, closeTo(expectedExtent, 1.0),
            reason: 'maxScrollExtent must be exact for the scrollbar to work');

        // Scrollbar drag: a sequence of large jumps across the document.
        final jumpSw = Stopwatch()..start();
        for (final fraction in [0.25, 0.9, 0.1, 1.0, 0.5]) {
          scroll.scrollController.jumpTo(position.maxScrollExtent * fraction);
          await tester.pump();
        }
        jumpSw.stop();
        final perJump = jumpSw.elapsedMilliseconds ~/ 5;

        // Continuous scroll, as a wheel or trackpad produces.
        final dragSw = Stopwatch()..start();
        for (var i = 0; i < 20; i++) {
          scroll.scrollController.jumpTo(position.pixels + 240);
          await tester.pump();
        }
        dragSw.stop();
        final perScrollStep = dragSw.elapsedMicroseconds ~/ 20;

        // Index-based navigation (search, go-to-definition).
        final seekSw = Stopwatch()..start();
        scroll.scrollToIndex(visible.length - 1, alignment: 0.5);
        await tester.pump();
        seekSw.stop();

        // ignore: avoid_print
        print('''
--- ~$target nodes (${visible.length} rows) ---
  first layout          ${layoutSw.elapsedMilliseconds} ms
  scrollbar jump        $perJump ms each (ceiling ${maxJumpMs} ms)
  continuous scroll     ${(perScrollStep / 1000).toStringAsFixed(2)} ms per step
  scrollToIndex(last)   ${seekSw.elapsedMilliseconds} ms
  maxScrollExtent       ${position.maxScrollExtent.toStringAsFixed(0)} px (exact)''');

        expect(perJump, lessThan(maxJumpMs),
            reason: 'scrollbar jumps must stay O(1) — this is the regression '
                'guard for the ScrollablePositionedList behaviour');
        expect(seekSw.elapsedMilliseconds, lessThan(maxJumpMs));
      }, timeout: const Timeout(Duration(minutes: 4)));
    }
  });
}
