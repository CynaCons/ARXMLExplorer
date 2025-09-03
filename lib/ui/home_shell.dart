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
import 'package:arxml_explorer/features/xsd/view/xsd_catalog_view.dart';

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
    final theme = Theme.of(context);
    final tabs = ref.watch(fileTabsProvider);
    final activeTab = ref.watch(activeTabProvider);
    final isLoading = ref.watch(loadingStateProvider);
    final navIndex = ref.watch(navRailIndexProvider);
    final activeIndex = ref.watch(activeTabIndexProvider);

    ref.listen(fileTabsProvider, (prev, next) {
      if (mounted) setState(() {});
    });

    _syncTabController(tabs.length, activeIndex);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navIndex,
            onDestinationSelected: (i) =>
                ref.read(navRailIndexProvider.notifier).state = i,
            labelType: NavigationRailLabelType.all,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ARXML\nExplorer',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Tooltip(message: 'Editor', child: Icon(Icons.edit_outlined)),
                selectedIcon: Tooltip(message: 'Editor', child: Icon(Icons.edit)),
                label: Text('Editor'),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                    message: 'Workspace',
                    child: Icon(Icons.folder_open_outlined)),
                selectedIcon:
                    Tooltip(message: 'Workspace', child: Icon(Icons.folder)),
                label: Text('Workspace'),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                    message: 'Validation',
                    child: Icon(Icons.rule_folder_outlined)),
                selectedIcon: Tooltip(
                    message: 'Validation', child: Icon(Icons.rule_folder)),
                label: Text('Validation'),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                    message: 'XSDs', child: Icon(Icons.schema_outlined)),
                selectedIcon:
                    Tooltip(message: 'XSDs', child: Icon(Icons.schema)),
                label: Text('XSDs'),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                    message: 'Settings',
                    child: Icon(Icons.settings_outlined)),
                selectedIcon:
                    Tooltip(message: 'Settings', child: Icon(Icons.settings)),
                label: Text('Settings'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Open File',
                        icon: const Icon(Icons.file_open_outlined),
                        onPressed: () =>
                            ref.read(fileTabsProvider.notifier).openNewFile(),
                      ),
                      IconButton(
                        tooltip: 'Create New File',
                        icon: const Icon(Icons.create_new_folder_outlined),
                        onPressed: () => ref
                            .read(fileTabsProvider.notifier)
                            .createNewFile(),
                      ),
                      IconButton(
                        tooltip: 'Search',
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          showSearch(
                            context: context,
                            delegate: CustomSearchDelegate(
                              null,
                              getTreeState: () {
                                final at = ref.read(activeTabProvider);
                                return at == null
                                    ? null
                                    : ref.read(at.treeStateProvider);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Builder(builder: (context) {
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

              Widget currentView;
              switch (navIndex) {
                case 1:
                  currentView = WorkspaceView(
                      onOpenFile: (fp) => ref
                          .read(fileTabsProvider.notifier)
                          .openFileAndNavigate(fp, shortNamePath: const []));
                  break;
                case 2:
                  currentView = ValidationView(
                      itemScrollController: itemScrollController);
                  break;
                case 3:
                  currentView = const XsdCatalogView();
                  break;
                case 4:
                  currentView = 
                      ListView(padding: const EdgeInsets.all(16), children: [
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
                      onChanged: (_) => ref
                          .read(fileTabsProvider.notifier)
                          .toggleDiagnostics(),
                    ),
                  ]);
                  break;
                default:
                  currentView = isLoading
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
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (navIndex == 0) tabsBar,
                  Expanded(child: currentView),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
