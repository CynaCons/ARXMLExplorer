import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/main.dart';

void main() {
  group('NavigationRail interactions', () {
    testWidgets('tapping destinations switches views', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: XmlExplorerApp()));
      await tester.pumpAndSettle();

      // Initially on Editor view (no file prompt)
      expect(find.text('Open a file to begin'), findsOneWidget);

      // Tap Workspace destination (index 1)
      final rail = find.byType(NavigationRail);
      expect(rail, findsOneWidget);

      // Destinations are built as custom tiles; select by tooltip label text
      await tester.tap(find.text('Workspace').first);
      await tester.pumpAndSettle();

      // Workspace view shows "Open Workspace" button when none selected
      expect(find.text('Open Workspace'), findsOneWidget);

      // Tap Validation destination
      await tester.tap(find.text('Validation').first);
      await tester.pumpAndSettle();

      // Validation view with empty state text
      expect(find.text('No validation issues to display'), findsOneWidget);

      // Tap Settings destination
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      // Settings view contains a Live validation switch
      expect(find.text('Live validation'), findsOneWidget);

      // Tap XSDs destination
      await tester.tap(find.text('XSDs').first);
      await tester.pumpAndSettle();

      // XSD Catalog view title (updated wording)
      expect(find.textContaining('XSD Catalog'), findsOneWidget);

      // Return to Editor by tapping the 'Editor' rail destination
      await tester.tap(find.text('Editor').first);
      await tester.pumpAndSettle();
      expect(find.text('Open a file to begin'), findsOneWidget);
    });
  });
}
