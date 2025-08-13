import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/arxml_tree_view_state.dart';

void main() {
  testWidgets('Add Child dialog shows validation hint when empty',
      (tester) async {
    final node = ElementNode(elementText: 'PARENT', children: [], depth: 0);
    final provider = arxmlTreeStateProvider([node]);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ElementNodeWidget(
            node: node,
            treeStateProvider: provider,
            xsdParser: null,
          ),
        ),
      ),
    ));

    // Open context menu and tap Add Child
    final tile = find.byType(ListTile);
    await tester.longPress(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Child'));
    await tester.pumpAndSettle();

    // Attempt to press Add with empty inputs
    final addButton = find.widgetWithText(TextButton, 'Add');
    expect(addButton, findsOneWidget);

    // Button should be disabled (onPressed null)
    final TextButton btn = tester.widget(addButton);
    expect(btn.onPressed, isNull);
  });
}
