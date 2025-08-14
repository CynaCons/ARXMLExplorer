import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/app.dart';
import 'ui/home_shell.dart';

void main() {
  runApp(const ProviderScope(child: AppRoot(home: HomeShell())));
}

class XmlExplorerApp extends StatelessWidget {
  const XmlExplorerApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const ProviderScope(child: AppRoot(home: HomeShell()));
}
