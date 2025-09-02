import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/features/editor/view/editor_view.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart'
    show
        fileTabsProvider,
        activeTabIndexProvider,
        activeTabProvider,
        loadingStateProvider,
        diagnosticsProvider;
import 'package:arxml_explorer/features/workspace/view/workspace_view.dart';
import 'package:arxml_explorer/features/validation/view/validation_view.dart';
import 'package:arxml_explorer/features/editor/view/widgets/search/custom_search_delegate.dart';

// Global navigation index used across views
final navRailIndexProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  late final ItemScrollController itemScrollController;
  late final ItemPositionsListener itemPositionsListener;

  @override
  void initState() {
    super.initState();
    itemScrollController = ItemScrollController();
    itemPositionsListener = ItemPositionsListener.create();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _syncTabController(int tabsLen, int activeIndex) {
    if (_tabController == null || _tabController!.length != tabsLen) {
      _tabController?.dispose();
      if (tabsLen > 0) {
        final safe = activeIndex.clamp(0, tabsLen - 1);
        _tabController =
            TabController(length: tabsLen, vsync: this, initialIndex: safe);
        // Ensure listeners dependent on TabController get a frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        _tabController = null;
      }
    } else {
      if (_tabController!.index != activeIndex && activeIndex < tabsLen) {
        _tabController!.index = activeIndex;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
  // ignore: avoid_print
  print('[home] build');
    final tabs = ref.watch(fileTabsProvider);
    final activeTab = ref.watch(activeTabProvider);
    final isLoading = ref.watch(loadingStateProvider);
    final navIndex = ref.watch(navRailIndexProvider);
    final activeIndex = ref.watch(activeTabIndexProvider);

    // Ensure UI rebuilds when tabs change (useful for programmatic tests)
  ref.listen(fileTabsProvider, (prev, next) {
      if (mounted) setState(() {});
    });

    _syncTabController(tabs.length, activeIndex);
  // ignore: avoid_print
  print('[home] tabs=${tabs.length} activeIndex=$activeIndex hasTC=${_tabController != null}');

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navIndex,
            onDestinationSelected: (i) =>
                ref.read(navRailIndexProvider.notifier).state = i,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Column(
                children: const [
                  CircleAvatar(
                    radius: 18,
                    child: Icon(Icons.settings_ethernet),
                  ),
                  SizedBox(height: 8),
                  // Keep name visible for tests and branding
                  Text('ARXML Explorer', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Tooltip(
                  message: 'Editor',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(height: 2),
                      Text('Editor', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                selectedIcon: Tooltip(
                  message: 'Editor',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit),
                      SizedBox(height: 2),
                      Text('Editor', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                label: SizedBox.shrink(),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                  message: 'Workspace',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open),
                      SizedBox(height: 2),
                      Text('Workspace', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                selectedIcon: Tooltip(
                  message: 'Workspace',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder),
                      SizedBox(height: 2),
                      Text('Workspace', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                label: SizedBox.shrink(),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                  message: 'Validation',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rule_folder_outlined),
                      SizedBox(height: 2),
                      Text('Validation', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                selectedIcon: Tooltip(
                  message: 'Validation',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rule_folder),
                      SizedBox(height: 2),
                      Text('Validation', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                label: SizedBox.shrink(),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                  message: 'Settings',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_outlined),
                      SizedBox(height: 2),
                      Text('Settings', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                selectedIcon: Tooltip(
                  message: 'Settings',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings),
                      SizedBox(height: 2),
                      Text('Settings', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                label: SizedBox.shrink(),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                  message: 'XSDs',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rule_folder_outlined),
                      SizedBox(height: 2),
                      Text('XSDs', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                selectedIcon: Tooltip(
                  message: 'XSDs',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rule_folder),
                      SizedBox(height: 2),
                      Text('XSDs', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                label: SizedBox.shrink(),
              ),
            ],
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Open File',
                    icon: const Icon(Icons.file_open),
                    onPressed: () =>
                        ref.read(fileTabsProvider.notifier).openNewFile(),
                  ),
                  IconButton(
                    tooltip: 'Create New File',
                    icon: const Icon(Icons.create_new_folder),
                    onPressed: () =>
                        ref.read(fileTabsProvider.notifier).createNewFile(),
                  ),
          IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: () async {
            // debug: trace search activation in tests
            // ignore: avoid_print
            print('[ui] search icon tapped');
                      // Allow early taps: wait briefly for an active tab if needed
                      // Show search immediately; delegate will resolve tree state lazily
                      // ignore: avoid_print
                      print('[ui] launching showSearch');
                      showSearch(
                        context: context,
                        delegate: CustomSearchDelegate(
                          null,
                          getTreeState: () {
                            final at = ref.read(activeTabProvider);
                            return at == null ? null : ref.read(at.treeStateProvider);
                          },
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Fit All / Reset View',
                    icon: const Icon(Icons.fit_screen),
                    onPressed: () =>
                        ref.read(navRailIndexProvider.notifier).state = 0,
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Builder(builder: (context) {
              // Tabs bar above editor when tabs exist
              final tabsBar = (tabs.isEmpty || _tabController == null)
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        controller: _tabController!,
                        isScrollable: true,
                        tabs: tabs
                            .map((tab) => Tab(
                                  child: Row(children: [
                                    Text(
                                      tab.path
                                          .split(Platform.pathSeparator)
                                          .last,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (tab.isDirty)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6.0),
                                        child: Tooltip(
                                            message: 'Unsaved changes',
                                            child: Icon(Icons.circle,
                                                size: 8,
                                                color: Colors.amber)),
                                      ),
                                  ]),
                                ))
                            .toList(),
                      ),
                    );

              if (navIndex == 1) {
                return WorkspaceView(
                    onOpenFile: (fp) => ref
                        .read(fileTabsProvider.notifier)
                        .openFileAndNavigate(fp, shortNamePath: const []));
              } else if (navIndex == 2) {
                return ValidationView(
                    itemScrollController: itemScrollController);
              } else if (navIndex == 3) {
                return ListView(padding: const EdgeInsets.all(16), children: [
                  SwitchListTile(
                    title: const Text('Live validation'),
                    subtitle: const Text('Validate while editing'),
                    value: ref.watch(liveValidationProvider),
                    onChanged: (v) =>
                        ref.read(liveValidationProvider.notifier).state = v,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Verbose XSD diagnostics'),
                    subtitle: const Text('Show parser resolution trace'),
                    value: ref.watch(diagnosticsProvider),
                    onChanged: (_) =>
                        ref.read(fileTabsProvider.notifier).toggleDiagnostics(),
                  ),
                ]);
              } else if (navIndex == 4) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    ListTile(title: Text('XSD Catalog')),
                  ],
                );
              }

              final editorArea = isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (activeTab != null && _tabController != null)
                      ? EditorView(
                          tabController: _tabController!,
                          itemScrollController: itemScrollController,
                          itemPositionsListener: itemPositionsListener,
                        )
                      : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text('Open a file to begin'),
                          ),
                        );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tabsBar,
                  Expanded(child: editorArea),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class ProviderApp extends StatelessWidget {
  final Widget child;
  const ProviderApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ProviderScope(child: child);
}

// _RailTile removed to keep rail compact and avoid overflow; using icon-only destinations.
