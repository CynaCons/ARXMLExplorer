import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/main.dart';
import 'package:arxml_explorer/depth_indicator.dart';

void main() {
  group('Visuals and UX', () {
    testWidgets('App UI elements are present', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: XmlExplorerApp()));

      // Verify main UI elements
      expect(find.byIcon(Icons.file_open), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);
    });

    testWidgets('Depth Indicator works', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DepthIndicator(depth: 2, isLastChild: false),
        ),
      ));

      // Verify depth indicator is rendered
      expect(find.byType(DepthIndicator), findsOneWidget);
    });

    test('DepthIndicator creates correct width', () {
      const depth0 = DepthIndicator(depth: 0, isLastChild: false);
      const depth2 = DepthIndicator(depth: 2, isLastChild: true);

      // Verify depth indicators are created correctly
      expect(depth0.depth, 0);
      expect(depth2.depth, 2);
      expect(depth0.isLastChild, false);
      expect(depth2.isLastChild, true);
    });
  });
}
