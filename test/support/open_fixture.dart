import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/ui/home_shell.dart';

/// Default ARXML fixture used by widget tests.
const String kGenericEcuFixture = 'test/res/generic_ecu.arxml';

/// Pumps [HomeShell] inside a ProviderScope and returns its container.
///
/// Widget tests used to open a file by tapping the Open File icon and relying
/// on `openNewFile()` silently preferring the fixture over the platform picker.
/// That shortcut is gone (it meant the real app never prompted), so tests now
/// drive the provider directly — which is also deterministic, with no dialog
/// timing to race.
Future<ProviderContainer> pumpShell(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Size surfaceSize = const Size(1280, 900),
  bool autoAttachSchema = false,
}) async {
  overrides = [
    // Parsing a real AUTOSAR XSD takes seconds on the main isolate. Off unless
    // the test is actually about schemas or validation.
    autoAttachSchemaProvider.overrideWith((ref) => autoAttachSchema),
    ...overrides,
  ];
  // The default 800x600 test surface is smaller than any real desktop window,
  // and the rail's trailing action column does not fit in 600px of height —
  // taps land off-screen and silently miss.
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: HomeShell()),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(HomeShell)));
}

/// Opens [path] in the editor and pumps until the tree has rendered.
///
/// `openNewFile` performs real `dart:io` reads. `testWidgets` runs the body in
/// a fake-async zone where those futures never complete, so the call must go
/// through [WidgetTester.runAsync] — awaiting it directly hangs until the test
/// times out.
///
/// Schema attachment is deliberately *not* awaited: parsing an AUTOSAR XSD
/// takes seconds. Pass `awaitSchema: true` in the few tests that need
/// validation to be live.
Future<void> openFixture(
  WidgetTester tester,
  ProviderContainer container, {
  String path = kGenericEcuFixture,
  bool awaitSchema = false,
  int maxPumps = 40,
}) async {
  final notifier = container.read(fileTabsProvider.notifier);

  await tester.runAsync(() async {
    await notifier.openNewFile(path: path);
    if (awaitSchema) await notifier.schemaWarmup;
  });

  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (container.read(fileTabsProvider).isNotEmpty &&
        !container.read(loadingStateProvider)) {
      break;
    }
  }
  // One more frame so the tab's tree view builds its rows.
  await tester.pump(const Duration(milliseconds: 50));

  expect(container.read(fileTabsProvider), isNotEmpty,
      reason: 'openNewFile(path: $path) did not create a tab '
          '(lastError: ${notifier.lastError})');
  expect(container.read(navRailIndexProvider), 0,
      reason: 'opening a file should switch to the Editor view');
}
