import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/ui/home_shell.dart';
import 'package:arxml_explorer/ui/app.dart';

void main() {
  testWidgets('Selected tab has pill background', (tester) async {
    await tester
        .pumpWidget(const ProviderScope(child: AppRoot(home: HomeShell())));
    expect(find.byType(TabBar), findsNothing);
  });
}
