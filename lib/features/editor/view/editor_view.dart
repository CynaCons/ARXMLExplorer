import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/services.dart';

import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart'
    show
        fileTabsProvider,
        activeTabProvider,
        diagnosticsProvider,
        scrollToIndexProvider;
import 'package:arxml_explorer/arxml_tree_view_state.dart'
    show FileTabState; // temp until refactor
import 'package:arxml_explorer/elementnodesearchdelegate.dart';

enum _NavDir {
  up,
  down,
  left,
  right,
  home,
  end,
  pageUp,
  pageDown,
  enter,
  focusSearch,
  clearSelection
}

class _NavIntent extends Intent {
  final _NavDir dir;
  const _NavIntent(this.dir);
}

class EditorView extends ConsumerStatefulWidget {
  final TabController tabController;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  const EditorView(
      {super.key,
      required this.tabController,
      required this.itemScrollController,
      required this.itemPositionsListener});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(fileTabsProvider);
    final activeTab = ref.watch(activeTabProvider);
    final diagnosticsOn = ref.watch(diagnosticsProvider);

    // Handle pending scroll (go-to-definition)
    final pendingScrollIndex = ref.watch(scrollToIndexProvider);
    if (pendingScrollIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.itemScrollController.scrollTo(
          index: pendingScrollIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        ref.read(scrollToIndexProvider.notifier).state = null;
      });
    }

    if (activeTab == null) {
      return const Center(child: Text('No file open'));
    }

    return Stack(
      children: [
        Column(
          children: [
            if (diagnosticsOn && activeTab.xsdParser != null)
              Container(
                height: 100,
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView(
                    children: activeTab.xsdParser!
                        .getLastResolutionTrace()
                        .map((e) => Text(e,
                            style: const TextStyle(color: Colors.white70)))
                        .toList(),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: widget.tabController,
                    isScrollable: true,
                    indicatorColor: Colors.transparent,
                    tabs: tabs
                        .map((tab) => Tab(
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: widget.tabController.index ==
                                              tabs.indexOf(tab)
                                          ? Colors.white.withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          tab.path
                                              .split(Platform.pathSeparator)
                                              .last,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                widget.tabController.index ==
                                                        tabs.indexOf(tab)
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                          ),
                                        ),
                                        if (tab.isDirty)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6.0),
                                            child: Tooltip(
                                              message: 'Unsaved changes',
                                              child: Icon(Icons.circle,
                                                  size: 8, color: Colors.amber),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (tab.xsdPath != null)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6.0),
                                      child: Icon(Icons.rule, size: 14),
                                    )
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: widget.tabController,
                      children: tabs.map((tab) {
                        return Consumer(builder: (context, ref, child) {
                          final treeState = ref.watch(tab.treeStateProvider);
                          final notifier =
                              ref.read(tab.treeStateProvider.notifier);
                          return FocusableActionDetector(
                            autofocus: true,
                            shortcuts: <LogicalKeySet, Intent>{
                              LogicalKeySet(LogicalKeyboardKey.arrowUp):
                                  const _NavIntent(_NavDir.up),
                              LogicalKeySet(LogicalKeyboardKey.arrowDown):
                                  const _NavIntent(_NavDir.down),
                              LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                                  const _NavIntent(_NavDir.left),
                              LogicalKeySet(LogicalKeyboardKey.arrowRight):
                                  const _NavIntent(_NavDir.right),
                              LogicalKeySet(LogicalKeyboardKey.home):
                                  const _NavIntent(_NavDir.home),
                              LogicalKeySet(LogicalKeyboardKey.end):
                                  const _NavIntent(_NavDir.end),
                              LogicalKeySet(LogicalKeyboardKey.pageUp):
                                  const _NavIntent(_NavDir.pageUp),
                              LogicalKeySet(LogicalKeyboardKey.pageDown):
                                  const _NavIntent(_NavDir.pageDown),
                              LogicalKeySet(LogicalKeyboardKey.enter):
                                  const _NavIntent(_NavDir.enter),
                              LogicalKeySet(LogicalKeyboardKey.keyF,
                                      LogicalKeyboardKey.control):
                                  const _NavIntent(_NavDir.focusSearch),
                              LogicalKeySet(LogicalKeyboardKey.escape):
                                  const _NavIntent(_NavDir.clearSelection),
                            },
                            actions: <Type, Action<Intent>>{
                              _NavIntent: CallbackAction<_NavIntent>(
                                onInvoke: (intent) {
                                  switch (intent.dir) {
                                    case _NavDir.up:
                                      notifier.selectUp();
                                      break;
                                    case _NavDir.down:
                                      notifier.selectDown();
                                      break;
                                    case _NavDir.left:
                                      notifier.collapseOrGoParent();
                                      break;
                                    case _NavDir.right:
                                      notifier.expandOrGoChild();
                                      break;
                                    case _NavDir.home:
                                      notifier.selectFirst();
                                      break;
                                    case _NavDir.end:
                                      notifier.selectLast();
                                      break;
                                    case _NavDir.pageUp:
                                      notifier.pageUp();
                                      break;
                                    case _NavDir.pageDown:
                                      notifier.pageDown();
                                      break;
                                    case _NavDir.enter:
                                      final treeStateCurrent =
                                          ref.read(tab.treeStateProvider);
                                      final selId =
                                          treeStateCurrent.selectedNodeId;
                                      if (selId != null) {
                                        final node =
                                            treeStateCurrent.flatMap[selId];
                                        if (node != null &&
                                            node.children.isEmpty) {
                                          showDialog(
                                              context: context,
                                              builder: (_) {
                                                final controller =
                                                    TextEditingController(
                                                        text: node.elementText);
                                                return AlertDialog(
                                                  title:
                                                      const Text('Edit Value'),
                                                  content: TextField(
                                                      controller: controller,
                                                      autofocus: true),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: const Text(
                                                            'Cancel')),
                                                    TextButton(
                                                        onPressed: () {
                                                          notifier
                                                              .editNodeValue(
                                                                  node.id,
                                                                  controller
                                                                      .text);
                                                          ref
                                                              .read(
                                                                  fileTabsProvider
                                                                      .notifier)
                                                              .markDirtyForTreeProvider(
                                                                  tab.treeStateProvider);
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child:
                                                            const Text('Save'))
                                                  ],
                                                );
                                              });
                                        } else if (node != null &&
                                            node.children.isNotEmpty) {
                                          notifier.toggleNodeCollapse(node.id);
                                        }
                                      }
                                      break;
                                    case _NavDir.focusSearch:
                                      final treeState =
                                          ref.read(tab.treeStateProvider);
                                      showSearch<int?>(
                                        context: context,
                                        delegate:
                                            CustomSearchDelegate(treeState),
                                      ).then((nodeId) {
                                        if (nodeId != null) {
                                          notifier.expandUntilNode(nodeId);
                                          final updated =
                                              ref.read(tab.treeStateProvider);
                                          final idx = updated.visibleNodes
                                              .indexWhere(
                                                  (n) => n.id == nodeId);
                                          if (idx != -1) {
                                            notifier.setSelected(nodeId);
                                            widget.itemScrollController
                                                .scrollTo(
                                              index: idx,
                                              duration: const Duration(
                                                  milliseconds: 250),
                                              curve: Curves.easeOutCubic,
                                            );
                                          }
                                        }
                                      });
                                      break;
                                    case _NavDir.clearSelection:
                                      notifier.setSelected(null);
                                      break;
                                  }
                                  // ensure visible after nav
                                  notifier.ensureSelectionVisible((idx) {
                                    widget.itemScrollController.scrollTo(
                                      index: idx,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      curve: Curves.easeOut,
                                    );
                                  });
                                  return null;
                                },
                              )
                            },
                            child: ScrollablePositionedList.builder(
                              itemScrollController: widget.itemScrollController,
                              itemPositionsListener:
                                  widget.itemPositionsListener,
                              itemCount: treeState.visibleNodes.length,
                              itemBuilder: (context, index) {
                                final node = treeState.visibleNodes[index];
                                final isSelected =
                                    node.id == treeState.selectedNodeId;
                                return GestureDetector(
                                  onTap: () => ref
                                      .read(tab.treeStateProvider.notifier)
                                      .setSelected(node.id),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.12)
                                          : null,
                                    ),
                                    child: ElementNodeWidget(
                                      node: node,
                                      xsdParser: tab.xsdParser,
                                      treeStateProvider: tab.treeStateProvider,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        });
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (ref.watch(showResourceHudProvider))
          Positioned(
            right: 8,
            bottom: 8,
            child: _EditorResourceHud(activeTab: activeTab),
          ),
      ],
    );
  }
}

class _EditorResourceHud extends ConsumerStatefulWidget {
  final FileTabState activeTab;
  const _EditorResourceHud({required this.activeTab});

  @override
  ConsumerState<_EditorResourceHud> createState() => _EditorResourceHudState();
}

class _EditorResourceHudState extends ConsumerState<_EditorResourceHud> {
  String _mem = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _update());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _update() async {
    try {
      final info = WidgetsBinding.instance.platformDispatcher;
      final estimates = <String>[];
      if (info.views.isNotEmpty) {
        estimates.add('views:${info.views.length}');
      }
      setState(() {
        _mem =
            'mem: ~N/A  |  nodes: ${_countNodes()}  |  ${estimates.join(' ')}';
      });
    } catch (_) {
      setState(() {
        _mem = 'nodes: ${_countNodes()}';
      });
    }
  }

  int _countNodes() {
    final tree = ref.watch(widget.activeTab.treeStateProvider);
    int count = 0;
    void walk(ElementNode n) {
      count++;
      for (final c in n.children) walk(c);
    }

    for (final r in tree.rootNodes) walk(r);
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70, fontSize: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(_mem),
          ],
        ),
      ),
    );
  }
}
