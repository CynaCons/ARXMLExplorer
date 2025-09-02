import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import '../editor.dart'; // For ARXMLTreeViewState
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/services.dart';

import 'package:arxml_explorer/features/editor/view/widgets/element_node/element_node_widget.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/features/editor/state/file_tabs_provider.dart'
    show
        fileTabsProvider,
        activeTabProvider,
        diagnosticsProvider,
        scrollToIndexProvider;
import 'package:arxml_explorer/features/editor/view/widgets/search/custom_search_delegate.dart';

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
  // ignore: avoid_print
  print('[editor] build');
    final tabs = ref.watch(fileTabsProvider);
    final activeTab = ref.watch(activeTabProvider);
    final diagnosticsOn = ref.watch(diagnosticsProvider);

    // Handle pending scroll (go-to-definition)
    final pendingScrollIndex = ref.watch(scrollToIndexProvider);
    if (pendingScrollIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final smooth = ref.read(smoothScrollingProvider);
        widget.itemScrollController.scrollTo(
          index: pendingScrollIndex,
          duration: smooth ? const Duration(milliseconds: 400) : Duration.zero,
          curve: Curves.easeInOut,
          alignment: 0.35,
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
            // Removed duplicate TabBar here; AppBar in HomeShell owns the tabs
            Expanded(
              child: TabBarView(
                controller: widget.tabController,
                children: tabs.map((tab) {
                  return Consumer(builder: (context, ref, child) {
                    final treeState = ref.watch(tab.treeStateProvider);
                    final notifier = ref.read(tab.treeStateProvider.notifier);
                    // Center pending node requests
                    if (treeState.pendingCenterNodeId != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final updated = ref.read(tab.treeStateProvider);
                        final idx = updated.visibleNodes.indexWhere(
                            (n) => n.id == updated.pendingCenterNodeId);
                        if (idx != -1) {
                          final smooth = ref.read(smoothScrollingProvider);
                          widget.itemScrollController.scrollTo(
                            index: idx,
                            duration: smooth
                                ? const Duration(milliseconds: 400)
                                : Duration.zero,
                            curve: Curves.easeInOut,
                            alignment: 0.35,
                          );
                        }
                        notifier.clearPendingCenter();
                      });
                    }
                    // ignore: avoid_print
                    print('[editor] tab build visible=${treeState.visibleNodes.length}');
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
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.5,
                                  );
                                });
                                break;
                              case _NavDir.down:
                                notifier.selectDown();
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.5,
                                  );
                                });
                                break;
                              case _NavDir.left:
                                notifier.collapseOrGoParent();
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.5,
                                  );
                                });
                                break;
                              case _NavDir.right:
                                notifier.expandOrGoChild();
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.5,
                                  );
                                });
                                break;
                              case _NavDir.home:
                                notifier.selectFirst();
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.5,
                                  );
                                });
                                break;
                              case _NavDir.end:
                                notifier.selectLast();
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.5,
                                  );
                                });
                                break;
                              case _NavDir.pageUp:
                                notifier.pageUp();
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.3,
                                  );
                                });
                                break;
                              case _NavDir.pageDown:
                                notifier.pageDown();
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.3,
                                  );
                                });
                                break;
                              case _NavDir.enter:
                                notifier.toggleExpandOrEdit((n) {
                                  // no-op in tests; editing handled in UI
                                });
                                ref
                                    .read(keyboardNavTickProvider.notifier)
                                    .state++;
                                notifier.ensureSelectionVisible((idx) {
                                  final smooth =
                                      ref.read(smoothScrollingProvider);
                                  widget.itemScrollController.scrollTo(
                                    index: idx,
                                    duration: smooth
                                        ? const Duration(milliseconds: 200)
                                        : Duration.zero,
                                    curve: Curves.easeOut,
                                    alignment: 0.5,
                                  );
                                });
                                break;
                              case _NavDir.focusSearch:
                                showSearch(
                                  context: context,
                                  delegate: CustomSearchDelegate(
                                    treeState,
                                  ),
                                );
                                break;
                              case _NavDir.clearSelection:
                                notifier.setSelected(null);
                                break;
                            }
                            return null;
                          },
                        ),
                      },
                      child: ScrollablePositionedList.separated(
                        itemScrollController: widget.itemScrollController,
                        itemPositionsListener: widget.itemPositionsListener,
                        // Use visibleNodes so expanded children are shown, not just roots
                        itemCount: treeState.visibleNodes.length,
                        itemBuilder: (context, index) {
                          final ElementNode node =
                              treeState.visibleNodes[index];
                          return ElementNodeWidget(
                            node: node,
                            xsdParser: tab.xsdParser,
                            treeStateProvider: tab.treeStateProvider,
                          );
                        },
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 0.2,
                        ),
                      ),
                    );
                  });
                }).toList(),
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
