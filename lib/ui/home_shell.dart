import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/features/editor/state/arxml_tree_view_state.dart'
    show FileTabState;
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
import 'package:arxml_explorer/features/xsd/state/xsd_catalog.dart';
import 'package:arxml_explorer/features/xsd/view/xsd_catalog_view.dart';

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
    // Scan for schemas once at start-up rather than lazily on the first
    // detection, so the XSDs view and the schema chooser are populated before
    // the user opens anything.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(xsdCatalogProvider.notifier).initialize();
    });
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

  // ---- Toolbar actions -------------------------------------------------
  // Save/undo/redo live on providers; the shell only dispatches to them so the
  // same handlers back both the rail buttons and the keyboard shortcuts.

  Future<void> _openFile() async {
    final notifier = ref.read(fileTabsProvider.notifier);
    await notifier.openNewFile();
    // openNewFile used to swallow every failure, so a bad read looked like the
    // button doing nothing. Surface it instead.
    final error = notifier.lastError;
    if (error != null && mounted) _toast(error);
  }

  Future<void> _save() async {
    await ref.read(fileTabsProvider.notifier).saveActiveFile();
    if (mounted) _toast('Saved');
  }

  Future<void> _saveAll() async {
    await ref.read(fileTabsProvider.notifier).saveAllFiles();
    if (mounted) _toast('All files saved');
  }

  bool _canUndo(FileTabState? tab) =>
      tab != null && ref.watch(tab.treeStateProvider).canUndo;

  bool _canRedo(FileTabState? tab) =>
      tab != null && ref.watch(tab.treeStateProvider).canRedo;

  void _undo() {
    final tab = ref.read(activeTabProvider);
    if (tab == null) return;
    ref.read(tab.treeStateProvider.notifier).undo();
    ref.read(fileTabsProvider.notifier).markDirtyForTreeProvider(
          tab.treeStateProvider,
        );
  }

  void _redo() {
    final tab = ref.read(activeTabProvider);
    if (tab == null) return;
    ref.read(tab.treeStateProvider.notifier).redo();
    ref.read(fileTabsProvider.notifier).markDirtyForTreeProvider(
          tab.treeStateProvider,
        );
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
      final previousLength = prev?.length ?? 0;
      if (next.length > previousLength && ref.read(navRailIndexProvider) != 0) {
        ref.read(navRailIndexProvider.notifier).state = 0;
      }
    });

    _syncTabController(tabs.length, activeIndex);

    return _ShellShortcuts(
      onSave: _save,
      onSaveAll: _saveAll,
      onUndo: _undo,
      onRedo: _redo,
      child: _buildScaffold(context, theme, tabs, activeTab, activeIndex,
          navIndex, isLoading),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ThemeData theme,
    List<FileTabState> tabs,
    FileTabState? activeTab,
    int activeIndex,
    int navIndex,
    bool isLoading,
  ) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navIndex,
            onDestinationSelected: (i) =>
                ref.read(navRailIndexProvider.notifier).state = i,
            labelType: NavigationRailLabelType.all,
            useIndicator: false,
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
            destinations: [
              _buildRailDestination(
                context,
                tooltip: 'Editor',
                label: 'Editor',
                icon: Icons.edit_outlined,
                selectedIcon: Icons.edit,
              ),
              _buildRailDestination(
                context,
                tooltip: 'Workspace',
                label: 'Workspace',
                icon: Icons.folder_open_outlined,
                selectedIcon: Icons.folder,
              ),
              _buildRailDestination(
                context,
                tooltip: 'Validation',
                label: 'Validation',
                icon: Icons.rule_folder_outlined,
                selectedIcon: Icons.rule_folder,
              ),
              _buildRailDestination(
                context,
                tooltip: 'XSDs',
                label: 'XSDs',
                icon: Icons.schema_outlined,
                selectedIcon: Icons.schema,
              ),
              _buildRailDestination(
                context,
                tooltip: 'Settings',
                label: 'Settings',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('action-open-file'),
                          tooltip: 'Open File',
                          icon: const Icon(Icons.file_open_outlined),
                          onPressed: _openFile,
                        ),
                        IconButton(
                          key: const Key('action-new-file'),
                          tooltip: 'Create New File',
                          icon: const Icon(Icons.create_new_folder_outlined),
                          onPressed: () => ref
                              .read(fileTabsProvider.notifier)
                              .createNewFile(),
                        ),
                        const Divider(indent: 12, endIndent: 12),
                        IconButton(
                          key: const Key('action-save'),
                          tooltip: 'Save  (Ctrl+S)',
                          icon: const Icon(Icons.save_outlined),
                          onPressed: activeTab == null ? null : _save,
                        ),
                        IconButton(
                          key: const Key('action-save-all'),
                          tooltip: 'Save All  (Ctrl+Shift+S)',
                          icon: const Icon(Icons.save_as_outlined),
                          onPressed: tabs.isEmpty ? null : _saveAll,
                        ),
                        IconButton(
                          key: const Key('action-undo'),
                          tooltip: 'Undo  (Ctrl+Z)',
                          icon: const Icon(Icons.undo),
                          onPressed: _canUndo(activeTab) ? _undo : null,
                        ),
                        IconButton(
                          key: const Key('action-redo'),
                          tooltip: 'Redo  (Ctrl+Y)',
                          icon: const Icon(Icons.redo),
                          onPressed: _canRedo(activeTab) ? _redo : null,
                        ),
                        const Divider(indent: 12, endIndent: 12),
                        IconButton(
                          key: const Key('action-search'),
                          tooltip: 'Search  (Ctrl+F)',
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
                        onTap: (index) => ref
                            .read(activeTabIndexProvider.notifier)
                            .state = index,
                        tabs: tabs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final tab = entry.value;
                          // p.basename handles both separators; splitting on
                          // Platform.pathSeparator mislabels tabs on Linux when
                          // a path carries Windows separators and vice versa.
                          final fileName = p.basename(tab.path);
                          return Tab(
                            child: _EditorTabLabel(
                              title: fileName,
                              isActive: activeIndex == idx,
                              isDirty: tab.isDirty,
                              onClose: () => ref
                                  .read(fileTabsProvider.notifier)
                                  .closeFile(idx),
                            ),
                          );
                        }).toList(),
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

enum _TabMenuAction { close }

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _SaveAllIntent extends Intent {
  const _SaveAllIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

/// App-level shortcuts for the file/edit actions exposed on the rail.
///
/// These sit above the editor's own navigation shortcuts so Ctrl+S works
/// regardless of which view has focus.
class _ShellShortcuts extends StatelessWidget {
  const _ShellShortcuts({
    required this.onSave,
    required this.onSaveAll,
    required this.onUndo,
    required this.onRedo,
    required this.child,
  });

  final VoidCallback onSave;
  final VoidCallback onSaveAll;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const _SaveIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS,
            control: true, shift: true): const _SaveAllIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            const _UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            const _RedoIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) => onSave.call()),
          _SaveAllIntent: CallbackAction<_SaveAllIntent>(
              onInvoke: (_) => onSaveAll.call()),
          _UndoIntent:
              CallbackAction<_UndoIntent>(onInvoke: (_) => onUndo.call()),
          _RedoIntent:
              CallbackAction<_RedoIntent>(onInvoke: (_) => onRedo.call()),
        },
        child: child,
      ),
    );
  }
}

NavigationRailDestination _buildRailDestination(
  BuildContext context, {
  required String tooltip,
  required String label,
  required IconData icon,
  IconData? selectedIcon,
}) {
  return NavigationRailDestination(
    icon: _SquareRailIcon(
      iconData: icon,
      tooltip: tooltip,
    ),
    selectedIcon: _SquareRailIcon(
      iconData: selectedIcon ?? icon,
      tooltip: tooltip,
      selected: true,
    ),
    label: Text(label),
  );
}

class _SquareRailIcon extends StatelessWidget {
  const _SquareRailIcon({
    required this.iconData,
    required this.tooltip,
    this.selected = false,
  });

  final IconData iconData;
  final String tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color:
              selected ? colors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : colors.outline.withOpacity(0.35),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          iconData,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EditorTabLabel extends StatelessWidget {
  const _EditorTabLabel({
    required this.title,
    required this.isActive,
    required this.isDirty,
    required this.onClose,
  });

  final String title;
  final bool isActive;
  final bool isDirty;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
      color: theme.textTheme.bodySmall?.color,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) async {
        final action = await showMenu<_TabMenuAction>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: const [
            PopupMenuItem<_TabMenuAction>(
              value: _TabMenuAction.close,
              child: Text('Close Tab'),
            ),
          ],
        );
        if (action == _TabMenuAction.close) {
          onClose();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive
              ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            if (isDirty)
              const Padding(
                padding: EdgeInsets.only(left: 6.0),
                child: Tooltip(
                  message: 'Unsaved changes',
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: Colors.amber,
                  ),
                ),
              ),
            IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              tooltip: 'Close tab',
              splashRadius: 18,
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
