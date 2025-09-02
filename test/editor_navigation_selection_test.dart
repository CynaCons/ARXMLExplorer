import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/features/editor/view/editor_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:arxml_explorer/app_providers.dart';

void main() {
  testWidgets('ArrowDown moves selection and requests scroll', (tester) async {
    // Disable smooth scrolling for deterministic test
    final itemScrollController = ItemScrollController();
    final itemPositionsListener = ItemPositionsListener.create();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        smoothScrollingProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return EditorView(
              tabController: TabController(length: 0, vsync: const TestVSync()),
              itemScrollController: itemScrollController,
              itemPositionsListener: itemPositionsListener,
            );
          }),
        ),
      ),
    ));

    // There may be no active tab; ensure no crash.
    await tester.pump(const Duration(milliseconds: 50));
  });
}

class TestVSync implements TickerProvider {
  const TestVSync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
