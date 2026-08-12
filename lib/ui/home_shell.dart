import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:arxml_explorer/features/editor/view/widgets/tree/tree_scroll_controller.dart';

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
  late final TreeScrollController treeScrollController;

  @override
  void initState() {
    super.initState();
    treeScrollController = TreeScrollController();
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
    treeScrollController.dispose();
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

  void _openSearch() {
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
  }

  void _onMoreAction(_MoreAction action) {
    switch (action) {
      case _MoreAction.newFile:
        ref.read(fileTabsProvider.notifier).createNewFile();
      case _MoreAction.saveAll:
        _saveAll();
      case _MoreAction.search:
        _openSearch();
    }
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
      child: _buildScaffold(
          context, theme, tabs, activeTab, activeIndex, navIndex, isLoading),
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
            // Material 3's own indicator: one soft pill behind the active
            // destination. Every icon used to carry its own 44x44 outlined box,
            // which put five competing boxes on screen at once.
            useIndicator: true,
            indicatorColor: theme.colorScheme.secondaryContainer,
            minWidth: 72,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
              child: Tooltip(
                message: 'ARXML Explorer',
                child: Icon(
                  Icons.account_tree_outlined,
                  size: 26,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.edit_outlined),
                selectedIcon: Icon(Icons.edit),
                label: Text('Editor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder_open_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('Workspace'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.rule_folder_outlined),
                selectedIcon: Icon(Icons.rule_folder),
                label: Text('Validation'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schema_outlined),
                selectedIcon: Icon(Icons.schema),
                label: Text('XSDs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  // Four primary actions plus one overflow, instead of seven
                  // buttons and two dividers stacked down the rail.
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
                          key: const Key('action-save'),
                          tooltip: 'Save  (Ctrl+S)',
                          icon: const Icon(Icons.save_outlined),
                          onPressed: activeTab == null ? null : _save,
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
                        PopupMenuButton<_MoreAction>(
                          key: const Key('action-more'),
                          tooltip: 'More actions',
                          icon: const Icon(Icons.more_horiz),
                          position: PopupMenuPosition.under,
                          onSelected: (action) => _onMoreAction(action),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              key: Key('action-new-file'),
                              value: _MoreAction.newFile,
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.note_add_outlined),
                                title: Text('New File'),
                              ),
                            ),
                            PopupMenuItem(
                              key: const Key('action-save-all'),
                              value: _MoreAction.saveAll,
                              enabled: tabs.isNotEmpty,
                              child: const ListTile(
                                dense: true,
                                leading: Icon(Icons.save_as_outlined),
                                title: Text('Save All'),
                                trailing: Text('Ctrl+Shift+S'),
                              ),
                            ),
                            const PopupMenuItem(
                              key: Key('action-search'),
                              value: _MoreAction.search,
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.search),
                                title: Text('Search'),
                                trailing: Text('Ctrl+F'),
                              ),
                            ),
                          ],
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
                      treeScrollController: treeScrollController);
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
                              treeScrollController: treeScrollController,
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

/// Secondary rail actions, moved off the rail into an overflow menu so the
/// primary four (Open, Save, Undo, Redo) stay visible without a stack of
/// seven buttons and two dividers running down the side.
enum _MoreAction { newFile, saveAll, search }

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
          _SaveIntent:
              CallbackAction<_SaveIntent>(onInvoke: (_) => onSave.call()),
          _SaveAllIntent:
              CallbackAction<_SaveAllIntent>(onInvoke: (_) => onSaveAll.call()),
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
