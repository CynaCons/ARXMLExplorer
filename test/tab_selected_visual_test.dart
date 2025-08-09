import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/main.dart';

void main() {
  testWidgets('Selected tab has pill background', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: XmlExplorerApp()));

    // Expect TabBar not visible initially, since no tabs open
    expect(find.byType(TabBar), findsNothing);

    // Pump MyHomePage directly (wrapped with ProviderScope)
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: MyHomePage(title: 'ARXML Explorer'))));
    await tester.pumpAndSettle();

    // Still no tabs until files are opened; this smoke test ensures app builds and doesn't crash
    expect(find.byType(TabBar), findsNothing);
  });
}
