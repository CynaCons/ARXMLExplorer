import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/arxml_validator.dart';
import 'package:arxml_explorer/features/workspace/view/workspace_view.dart';
import 'package:arxml_explorer/features/validation/view/validation_view.dart';
import 'package:arxml_explorer/features/editor/view/editor_view.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart';
import 'package:arxml_explorer/workspace_indexer.dart';

// Shell-level providers
final navRailIndexProvider = StateProvider<int>((ref) => 0);
final validationFilterProvider = StateProvider<String>((ref) => '');

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  void _syncTabController(List<FileTabState> tabs, int activeTabIndex) {
    if (_tabController == null || _tabController!.length != tabs.length) {
      _tabController?.dispose();
      if (tabs.isNotEmpty) {
        final safe = activeTabIndex.clamp(0, tabs.length - 1);
        _tabController =
            TabController(length: tabs.length, vsync: this, initialIndex: safe);
        _tabController!.addListener(() {
          if (!_tabController!.indexIsChanging) {
            ref.read(activeTabIndexProvider.notifier).state =
                _tabController!.index;
          }
        });
      } else {
        _tabController = null;
      }
    } else if (_tabController != null) {
      final safe = activeTabIndex.clamp(0, tabs.length - 1);
      if (_tabController!.index != safe) {
        _tabController!.animateTo(safe);
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(fileTabsProvider);
    final activeIndex = ref.watch(activeTabIndexProvider);
    final activeTab = ref.watch(activeTabProvider);
    final notifier = ref.read(fileTabsProvider.notifier);
    final isLoading = ref.watch(loadingStateProvider);
    final diagnosticsOn = ref.watch(diagnosticsProvider);
    final liveValidationOn = ref.watch(liveValidationProvider);
    final navIndex = ref.watch(navRailIndexProvider);
    final issues = ref.watch(validationIssuesProvider);
    final highContrast = ref.watch(highContrastUiProvider);

    _syncTabController(tabs, activeIndex);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARXML Explorer'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.file_open),
              onPressed: notifier.openNewFile),
          IconButton(
              icon: const Icon(Icons.create_new_folder),
              onPressed: notifier.createNewFile),
          IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Save All',
              onPressed: notifier.saveAllFiles),
          if (activeTab != null && activeTab.xsdPath != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Tooltip(
                message:
                    'Schema: ${activeTab.xsdPath!.split(Platform.pathSeparator).last}',
                child: ActionChip(
                  label: Text(
                      activeTab.xsdPath!.split(Platform.pathSeparator).last,
                      style: const TextStyle(color: Colors.white)),
                  avatar: const Icon(Icons.rule, size: 16, color: Colors.white),
                  backgroundColor: Colors.white24,
                  onPressed: notifier.pickXsdForActiveTab,
                ),
              ),
            ),
          if (activeTab != null && activeTab.xsdPath != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: notifier.resetXsdForActiveTabToSession,
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Use session XSD'),
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Workspace',
            onPressed: () => ref
                .read(workspaceIndexProvider.notifier)
                .pickAndIndexWorkspace(),
          ),
          IconButton(
              icon: const Icon(Icons.save), onPressed: notifier.saveActiveFile),
          IconButton(
              icon: const Icon(Icons.file_present),
              tooltip: 'Select XSD schema',
              onPressed: notifier.pickXsdForActiveTab),
          IconButton(
            icon: Icon(
                diagnosticsOn ? Icons.bug_report : Icons.bug_report_outlined,
                color: diagnosticsOn
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.white),
            tooltip: diagnosticsOn
                ? 'Verbose XSD diagnostics: ON'
                : 'Verbose XSD diagnostics: OFF',
            onPressed: () =>
                ref.read(fileTabsProvider.notifier).toggleDiagnostics(),
          ),
          IconButton(
            icon: Icon(
                liveValidationOn
                    ? Icons.health_and_safety
                    : Icons.health_and_safety_outlined,
                color: liveValidationOn
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.white),
            tooltip: liveValidationOn
                ? 'Live validation: ON'
                : 'Live validation: OFF',
            onPressed: () {
              final next = !ref.read(liveValidationProvider);
              ref.read(liveValidationProvider.notifier).state = next;
              if (next) {
                ref
                    .read(validationSchedulerProvider.notifier)
                    .schedule(delay: const Duration(milliseconds: 100));
              }
            },
          ),
          if (activeTab != null && activeTab.xsdParser != null)
            IconButton(
              icon: const Icon(Icons.rule),
              tooltip: 'Validate current document',
              onPressed: () async {
                final tree = ref.read(activeTab.treeStateProvider);
                final parser = activeTab.xsdParser!;
                final validator = const ArxmlValidator();
                final opts = ref.read(validationOptionsProvider);
                final issues =
                    validator.validate(tree.rootNodes, parser, options: opts);
                ref.read(validationIssuesProvider.notifier).state = issues;
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Validation Report'),
                    content: SizedBox(
                      width: 600,
                      child: issues.isEmpty
                          ? const Text('No issues found')
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: issues
                                    .map((i) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child:
                                              Text('- ${i.path}: ${i.message}'),
                                        ))
                                    .toList(),
                              ),
                            ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'))
                    ],
                  ),
                );
              },
            ),
          IconButton(
            tooltip: issues.isEmpty
                ? 'No validation issues'
                : 'Validation issues: ${issues.length} — open results',
            onPressed: () => ref.read(navRailIndexProvider.notifier).state = 2,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.rule_folder_outlined),
                if (issues.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.redAccent, shape: BoxShape.circle),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                            issues.length > 99 ? '99+' : '${issues.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: tabs.isEmpty || _tabController == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController!,
                    isScrollable: true,
                    indicatorColor: Colors.transparent,
                    tabs: tabs
                        .map((tab) => Tab(
                              child: Row(children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _tabController != null &&
                                            tabs.indexOf(tab) ==
                                                _tabController!.index
                                        ? Colors.white.withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(children: [
                                    Text(
                                        tab.path
                                            .split(Platform.pathSeparator)
                                            .last,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: _tabController !=
                                                        null &&
                                                    tabs.indexOf(tab) ==
                                                        _tabController!.index
                                                ? FontWeight.w700
                                                : FontWeight.w500)),
                                    if (tab.isDirty)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6.0),
                                        child: Tooltip(
                                            message: 'Unsaved changes',
                                            child: Icon(Icons.circle,
                                                size: 8, color: Colors.amber)),
                                      ),
                                  ]),
                                ),
                                if (tab.xsdPath != null)
                                  const Padding(
                                      padding: EdgeInsets.only(left: 6.0),
                                      child: Icon(Icons.rule, size: 14))
                              ]),
                            ))
                        .toList(),
                  ),
                ),
        ),
      ),
      body: Row(
        children: [
          // Redesigned navigation rail panel
          Container(
            width: MediaQuery.of(context).size.width >= 1000 ? 96 : 78,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceVariant
                  .withOpacity(0.35),
              border: Border(
                right: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.4),
                    width: 1),
              ),
            ),
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: navIndex,
              onDestinationSelected: (i) =>
                  ref.read(navRailIndexProvider.notifier).state = i,
              labelType: MediaQuery.of(context).size.width >= 1000
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.selected,
              useIndicator: true,
              groupAlignment: -0.9,
              indicatorColor: highContrast
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.primary.withOpacity(0.18),
              indicatorShape: highContrast
                  ? RoundedRectangleBorder(
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.onPrimary,
                          width: 2),
                      borderRadius: BorderRadius.circular(4))
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
              destinations: [
                NavigationRailDestination(
                  icon: _AnimatedRailDestination(
                    tooltip: 'Editor',
                    icon: Icons.article_outlined,
                    selectedIcon: Icons.article,
                    label: 'Editor',
                    selected: navIndex == 0,
                    highContrast: highContrast,
                  ),
                  selectedIcon: _AnimatedRailDestination(
                    tooltip: 'Editor',
                    icon: Icons.article_outlined,
                    selectedIcon: Icons.article,
                    label: 'Editor',
                    selected: navIndex == 0,
                    highContrast: highContrast,
                  ),
                  label: const SizedBox.shrink(),
                ),
                NavigationRailDestination(
                  icon: _AnimatedRailDestination(
                    tooltip: 'Workspace',
                    icon: Icons.folder_outlined,
                    selectedIcon: Icons.folder,
                    label: 'Workspace',
                    selected: navIndex == 1,
                    highContrast: highContrast,
                  ),
                  selectedIcon: _AnimatedRailDestination(
                    tooltip: 'Workspace',
                    icon: Icons.folder_outlined,
                    selectedIcon: Icons.folder,
                    label: 'Workspace',
                    selected: navIndex == 1,
                    highContrast: highContrast,
                  ),
                  label: const SizedBox.shrink(),
                ),
                NavigationRailDestination(
                  icon: _AnimatedRailDestination(
                    tooltip: 'Validation',
                    icon: Icons.rule_outlined,
                    selectedIcon: Icons.rule,
                    label: 'Validation',
                    selected: navIndex == 2,
                    highContrast: highContrast,
                  ),
                  selectedIcon: _AnimatedRailDestination(
                    tooltip: 'Validation',
                    icon: Icons.rule_outlined,
                    selectedIcon: Icons.rule,
                    label: 'Validation',
                    selected: navIndex == 2,
                    highContrast: highContrast,
                  ),
                  label: const SizedBox.shrink(),
                ),
                NavigationRailDestination(
                  icon: _AnimatedRailDestination(
                    tooltip: 'Settings',
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    selected: navIndex == 3,
                    highContrast: highContrast,
                  ),
                  selectedIcon: _AnimatedRailDestination(
                    tooltip: 'Settings',
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    selected: navIndex == 3,
                    highContrast: highContrast,
                  ),
                  label: const SizedBox.shrink(),
                ),
              ],
              leading: Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('ARX',
                          style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer)),
                    ),
                  ],
                ),
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    IconButton(
                      tooltip: 'Fit All / Reset View',
                      icon: const Icon(Icons.fit_screen),
                      onPressed: () =>
                          ref.read(navRailIndexProvider.notifier).state = 0,
                    ),
                  ],
                ),
              ),
              selectedIconTheme: IconThemeData(
                  size: 26,
                  color: Theme.of(context).colorScheme.primary,
                  shadows: [
                    Shadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.4),
                        blurRadius: 6)
                  ]),
              unselectedIconTheme: IconThemeData(
                size: 24,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              ),
              selectedLabelTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              unselectedLabelTextStyle: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Builder(builder: (context) {
              if (navIndex == 1) {
                return WorkspaceView(
                    onOpenFile: (fp) => ref
                        .read(fileTabsProvider.notifier)
                        .openFileAndNavigate(fp, shortNamePath: const []));
              } else if (navIndex == 2) {
                return ValidationView(
                    itemScrollController: itemScrollController);
              } else if (navIndex == 3) {
                final opts = ref.watch(validationOptionsProvider);
                return ListView(padding: const EdgeInsets.all(16), children: [
                  SwitchListTile(
                      title: const Text('Live validation'),
                      subtitle: const Text('Validate while editing'),
                      value: ref.watch(liveValidationProvider),
                      onChanged: (v) {
                        ref.read(liveValidationProvider.notifier).state = v;
                        if (v)
                          ref
                              .read(validationSchedulerProvider.notifier)
                              .schedule(
                                  delay: const Duration(milliseconds: 100));
                      }),
                  const Divider(),
                  SwitchListTile(
                      title: const Text('Verbose XSD diagnostics'),
                      subtitle: const Text('Show parser resolution trace'),
                      value: ref.watch(diagnosticsProvider),
                      onChanged: (_) {
                        ref.read(fileTabsProvider.notifier).toggleDiagnostics();
                      }),
                  const Divider(),
                  SwitchListTile(
                      title: const Text('Ignore ADMIN-DATA in validation'),
                      subtitle: const Text(
                          'Omit ADMIN-DATA subtree from validation results'),
                      value: opts.ignoreAdminData,
                      onChanged: (v) {
                        ref.read(validationOptionsProvider.notifier).state =
                            ValidationOptions(ignoreAdminData: v);
                        ref
                            .read(validationSchedulerProvider.notifier)
                            .schedule(delay: const Duration(milliseconds: 100));
                      }),
                  const Divider(),
                  SwitchListTile(
                      title: const Text('Show Resource HUD (bottom-right)'),
                      subtitle: const Text(
                          'Displays app memory and model size (debug estimates)'),
                      value: ref.watch(showResourceHudProvider),
                      onChanged: (v) =>
                          ref.read(showResourceHudProvider.notifier).state = v),
                  const Divider(),
                  SwitchListTile(
                      title: const Text('High contrast UI mode'),
                      subtitle:
                          const Text('Solid indicators and stronger outlines'),
                      value: ref.watch(highContrastUiProvider),
                      onChanged: (v) =>
                          ref.read(highContrastUiProvider.notifier).state = v),
                ]);
              }
              return isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (activeTab != null && _tabController != null)
                      ? EditorView(
                          tabController: _tabController!,
                          itemScrollController: itemScrollController,
                          itemPositionsListener: itemPositionsListener)
                      : const SizedBox.shrink();
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
  Widget build(BuildContext context) {
    return ProviderScope(child: child);
  }
}

class _AnimatedRailDestination extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool highContrast;
  const _AnimatedRailDestination({
    required this.tooltip,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.highContrast,
  });

  @override
  State<_AnimatedRailDestination> createState() =>
      _AnimatedRailDestinationState();
}

class _AnimatedRailDestinationState extends State<_AnimatedRailDestination>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    if (widget.selected) _c.value = 1;
  }

  @override
  void didUpdateWidget(covariant _AnimatedRailDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _c.forward();
      } else {
        _c.reverse();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 0.9, end: 1.05)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    final fade = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeIn));
    final iconColor = widget.selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.65);
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Opacity(
          opacity: fade.value,
          child: Transform.scale(
            scale: scale.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.selected ? widget.selectedIcon : widget.icon,
                    color: iconColor),
                const SizedBox(height: 4),
                Text(widget.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            widget.selected ? FontWeight.w600 : FontWeight.w500,
                        color: widget.selected
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(
                                    MediaQuery.of(context).size.width >= 1000
                                        ? 0.85
                                        : 0.55)))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
