import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';

void main() {
  test('FileTabsNotifier switches navigation to editor when opening a file',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('arxml_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}/sample.arxml');
    await file.writeAsString(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<AUTOSAR/>',
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(navRailIndexProvider.notifier).state = 2;

    final tabsNotifier = container.read(fileTabsProvider.notifier);
    await tabsNotifier.openFileAndNavigate(file.path, shortNamePath: const []);

    expect(container.read(navRailIndexProvider), 0);
    final tabs = container.read(fileTabsProvider);
    expect(tabs, isNotEmpty);
    expect(tabs.first.path, file.path);
  });
}
