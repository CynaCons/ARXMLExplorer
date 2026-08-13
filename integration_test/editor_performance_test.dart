import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';
import 'package:arxml_explorer/ui/home_shell.dart';

import '../test/support/arxml_generator.dart';
import 'support/frame_stats.dart';

/// Headed end-to-end performance suite.
///
/// Run against a real window:
///   flutter test integration_test/editor_performance_test.dart -d windows
///   flutter test integration_test/editor_performance_test.dart -d linux
///
/// Unlike the widget benchmarks in test/performance/, this drives the real app
/// with real gestures on a real raster pipeline, so the FrameTiming numbers are
/// what the user actually experiences. The widget benchmarks stay useful for
/// fast relative comparisons in CI; this one is the ground truth.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ~50k nodes, matching the sample file used for manual inspection.
  const targetNodes = 50000;

  late Directory tmp;
  late String fixturePath;
  final results = <FrameStats>[];

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('arxml_e2e');
    fixturePath = '${tmp.path}${Platform.pathSeparator}large.arxml';
    await File(fixturePath)
        .writeAsString(generateArxml(targetNodes: targetNodes));
  });

  tearDownAll(() async {
    // ignore: avoid_print
    print('\n=== e2e frame timings (real window, $targetNodes-node file) ===');
    // ignore: avoid_print
    print(FrameStats.tableHeader);
    for (final r in results) {
      // ignore: avoid_print
      print(r.row);
    }
    // ignore: avoid_print
    print('budget: ${FrameStats.budgetMs.toStringAsFixed(1)} ms/frame '
        '(60fps). "janky" = frames over budget.\n');
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Boots the real shell with the fixture open and everything expanded.
  Future<ProviderContainer> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeShell())),
    );
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeShell)));

    await container
        .read(fileTabsProvider.notifier)
        .openNewFile(path: fixturePath);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(container.read(fileTabsProvider), isNotEmpty,
        reason: 'fixture failed to open');

    final tab = container.read(activeTabProvider)!;
    container.read(tab.treeStateProvider.notifier).expandAll();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return container;
  }

  /// Runs [body] while capturing frames, records the result, returns the stats.
  Future<FrameStats> capture(
    String label,
    Future<void> Function() body,
  ) async {
    final stats = FrameStats(label)..start();
    await body();
    stats.stop();
    results.add(stats);
    // ignore: avoid_print
    print('\n${stats.report()}');
    return stats;
  }

  Finder listFinder() => find.byType(Scrollable).first;

  testWidgets('opening a large file stays responsive', (tester) async {
    final stats = FrameStats('open + expandAll')..start();
    await boot(tester);
    stats.stop();
    results.add(stats);
    // ignore: avoid_print
    print('\n${stats.report()}');

    expect(find.byType(ElementNodeWidget), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('continuous drag scrolling', (tester) async {
    await boot(tester);

    await capture('drag scroll', () async {
      final centre = tester.getCenter(listFinder());
      for (var i = 0; i < 30; i++) {
        await tester.drag(listFinder(), const Offset(0, -400));
        await tester.pump();
      }
      // Scroll back up so the scenario is symmetric.
      for (var i = 0; i < 30; i++) {
        await tester.drag(listFinder(), const Offset(0, 400));
        await tester.pump();
      }
      debugPrint('drag centre was $centre');
    });
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('fling scrolling', (tester) async {
    await boot(tester);

    await capture('fling scroll', () async {
      for (var i = 0; i < 8; i++) {
        await tester.fling(listFinder(), const Offset(0, -1200), 4000);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
      }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('mouse wheel scrolling', (tester) async {
    await boot(tester);

    await capture('mouse wheel', () async {
      final centre = tester.getCenter(listFinder());
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(centre));
      for (var i = 0; i < 120; i++) {
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
        await tester.pump();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('dragging the scrollbar across the document', (tester) async {
    await boot(tester);

    // This is the interaction that used to freeze the app: with
    // ScrollablePositionedList a single jump took 16.6 s at 10k rows.
    await capture('scrollbar drag', () async {
      final scrollbar = find.byType(Scrollbar).first;
      final box = tester.getRect(scrollbar);
      // Grab near the top of the track and sweep down, then back up.
      final start = Offset(box.right - 8, box.top + 20);
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, box.height / 24));
        await tester.pump();
      }
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, -box.height / 24));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    });
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('keyboard navigation through the document', (tester) async {
    await boot(tester);

    await capture('keyboard nav', () async {
      for (var i = 0; i < 150; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('clicking rows to select', (tester) async {
    final container = await boot(tester);

    await capture('row selection clicks', () async {
      for (var i = 0; i < 40; i++) {
        final rows = find.byType(ElementNodeWidget);
        final n = rows.evaluate().length;
        if (n == 0) break;
        await tester.tap(rows.at(i % n), warnIfMissed: false);
        await tester.pump();
      }
    });

    final tab = container.read(activeTabProvider)!;
    expect(container.read(tab.treeStateProvider).selectedNodeId, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('expanding and collapsing the whole document', (tester) async {
    final container = await boot(tester);
    final tab = container.read(activeTabProvider)!;
    final notifier = container.read(tab.treeStateProvider.notifier);

    await capture('expand / collapse all', () async {
      for (var i = 0; i < 5; i++) {
        notifier.collapseAll();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        notifier.expandAll();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
      }
    });
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('seeking to distant nodes', (tester) async {
    final container = await boot(tester);
    final tab = container.read(activeTabProvider)!;
    final visible = container.read(tab.treeStateProvider).visibleNodes;

    await capture('seek across document', () async {
      for (final fraction in [0.9, 0.1, 0.5, 1.0, 0.0, 0.75, 0.25]) {
        final idx = ((visible.length - 1) * fraction)
            .round()
            .clamp(0, visible.length - 1);
        container.read(scrollToIndexProvider.notifier).state = idx;
        await tester.pumpAndSettle(const Duration(milliseconds: 600));
      }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('performance budget', (tester) async {
    // Two gates with different strictness, reflecting what is actually fixed.
    //
    // SCROLLING is fixed and must stay fixed. These were the scenarios that
    // froze the app (ScrollablePositionedList) and stuttered (IconButton per
    // row). They now run at 3-5 ms p50 with 0-2% janky frames, so they get a
    // real gate.
    //
    // SELECTION / KEYBOARD / STRUCTURE are known-open. Arrow keys and row
    // clicks sit around 30 ms per frame. Two fixes were tried and neither moved
    // the number: decoupling the list from selection state (so the whole list
    // stops rebuilding) and replacing three O(n) scans over 41k visible nodes
    // with an O(1) index. Both are correct improvements; neither was the
    // dominant cost. Root cause still unknown — it needs a real profile, not
    // another guess. These get a loose gate that only catches a total collapse.
    expect(results, isNotEmpty, reason: 'no scenarios were captured');

    const scrollScenarios = {
      'drag scroll',
      'fling scroll',
      'mouse wheel',
      'scrollbar drag',
    };

    final failures = <String>[];
    for (final r in results) {
      if (r.frameCount < 5) continue;

      if (scrollScenarios.contains(r.label)) {
        if (r.jankPercent > 15) {
          failures.add('${r.label}: ${r.jankPercent.toStringAsFixed(0)}% of '
              'frames over budget (scroll must stay under 15%)');
        }
        if (r.worstMs > 250) {
          failures.add('${r.label}: worst frame '
              '${r.worstMs.toStringAsFixed(0)} ms (scroll must stay under '
              '250 ms — a 16.6 s freeze is what this guards against)');
        }
      } else if (r.worstMs > 3000) {
        failures.add('${r.label}: worst frame '
            '${r.worstMs.toStringAsFixed(0)} ms — the app is hanging');
      }
    }

    final detail = failures.join('; ');
    expect(failures, isEmpty, reason: 'performance gates failed: $detail');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
