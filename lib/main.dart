import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'package:arxml_explorer/arxml_validator.dart';
import 'elementnodewidget.dart';
import 'arxmlloader.dart';
import 'elementnodesearchdelegate.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'workspace_indexer.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/ast_cache.dart';

// Providers
final fileTabsProvider =
    StateNotifierProvider<FileTabsNotifier, List<FileTabState>>((ref) {
  return FileTabsNotifier(ref);
});

final loadingStateProvider = StateProvider<bool>((ref) => false);
final diagnosticsProvider = StateProvider<bool>((ref) => false);

final activeTabIndexProvider = StateProvider<int>((ref) => 0);

final activeTabProvider = Provider<FileTabState?>((ref) {
  final tabs = ref.watch(fileTabsProvider);
  final activeTabIndex = ref.watch(activeTabIndexProvider);
  if (tabs.isEmpty || activeTabIndex >= tabs.length) return null;
  return tabs[activeTabIndex];
});

// Debounced validation scheduler (driven by liveValidationProvider)
final validationSchedulerProvider =
    StateNotifierProvider<ValidationScheduler, int>((ref) {
  return ValidationScheduler(ref);
});

class ValidationScheduler extends StateNotifier<int> {
  final Ref ref;
  Timer? _debounce;
  ValidationScheduler(this.ref) : super(0);

  void schedule({Duration delay = const Duration(milliseconds: 400)}) {
    if (!ref.read(liveValidationProvider)) return;
    _debounce?.cancel();
    _debounce = Timer(delay, _run);
  }

  void _run() {
    final tab = ref.read(activeTabProvider);
    if (tab == null || tab.xsdParser == null) return;
    final tree = ref.read(tab.treeStateProvider);
    final parser = tab.xsdParser!;
    final validator = const ArxmlValidator();
    final issues = validator.validate(tree.rootNodes, parser);
    ref.read(validationIssuesProvider.notifier).state = issues;
    state++; // bump version for any listeners
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

// UI scroll request for navigation (index in visible list)
final scrollToIndexProvider = StateProvider<int?>((ref) => null);

// State Notifier
class FileTabsNotifier extends StateNotifier<List<FileTabState>> {
  final Ref _ref;
  FileTabsNotifier(this._ref) : super([]);

  final ARXMLFileLoader _arxmlLoader = const ARXMLFileLoader();
  // Current schema for session (persisted in memory)
  XsdParser? _currentXsdParser;
  String? _currentXsdPath;

  // Load the default AUTOSAR XSD schema into current session schema
  Future<void> _loadXsdSchema() async {
    if (_currentXsdParser != null) return; // Already loaded

    try {
      final xsdFile = File('lib/res/xsd/AUTOSAR_00050.xsd');
      if (await xsdFile.exists()) {
        _currentXsdPath = xsdFile.path;
        final xsdContent = await xsdFile.readAsString();
        final verbose = _ref.read(diagnosticsProvider);
        _currentXsdParser = XsdParser(xsdContent, verbose: verbose);
      }
    } catch (e) {
      // Schema loading failed, continue without schema validation
      print('Warning: Could not load XSD schema: $e');
    }
  }

  Future<void> toggleDiagnostics() async {
    final next = !_ref.read(diagnosticsProvider);
    _ref.read(diagnosticsProvider.notifier).state = next;
    await _rebuildParsersWithVerbose(next);
  }

  Future<void> _rebuildParsersWithVerbose(bool verbose) async {
    // Rebuild session parser
    if (_currentXsdPath != null) {
      try {
        final content = await File(_currentXsdPath!).readAsString();
        _currentXsdParser = XsdParser(content, verbose: verbose);
      } catch (e) {
        print('Warning: Could not reload session XSD: $e');
      }
    }

    // Rebuild per-tab parsers
    final updated = <FileTabState>[];
    for (final tab in state) {
      XsdParser? parser = tab.xsdParser;
      if (tab.xsdPath != null) {
        try {
          final content = await File(tab.xsdPath!).readAsString();
          parser = XsdParser(content, verbose: verbose);
        } catch (e) {
          print('Warning: Could not reload XSD for tab ${tab.path}: $e');
        }
      } else {
        // Use current session parser
        parser = _currentXsdParser;
      }
      updated.add(FileTabState(
        path: tab.path,
        treeStateProvider: tab.treeStateProvider,
        xsdParser: parser,
        xsdPath: tab.xsdPath,
      ));
    }
    state = updated;
  }

  // Attempt to detect AUTOSAR schema reference/version from ARXML header
  Future<String?> _detectSchemaPathFromArxml(String content) async {
    // Look for explicit schemaLocation hints or AUTOSAR version in top-level tag
    // e.g., xmlns:xsi and xsi:schemaLocation or AUTOSAR/@xsi:noNamespaceSchemaLocation
    final lines = content.split(RegExp(r'\r?\n')).take(50).join('\n');
    final schemaLocMatch =
        RegExp(r'schemaLocation\s*=\s*"([^"]+)"').firstMatch(lines);
    if (schemaLocMatch != null) {
      final loc = schemaLocMatch.group(1)!;
      // If it references a known local file name, try to map to lib/res/xsd
      final filename = loc.split(RegExp(r'[\\/]')).last;
      final candidate = 'lib/res/xsd/' + filename;
      if (await File(candidate).exists()) return candidate;
    }

    final versionMatch =
        RegExp(r'AUTOSAR[^>]*version\s*=\s*"([^"]+)"').firstMatch(lines);
    if (versionMatch != null) {
      final ver = versionMatch.group(1)!.trim();
      // Known mapping examples in repo
      final candidates = [
        'lib/res/xsd/AUTOSAR_$ver.xsd',
        'lib/res/xsd/AUTOSAR_${ver.replaceAll('.', '-')}.xsd',
        'lib/res/xsd/AUTOSAR_00050.xsd',
      ];
      for (final c in candidates) {
        if (await File(c).exists()) return c;
      }
    }
    return null;
  }

  // Load the XSD schema for the active tab from file picker
  Future<void> pickXsdForActiveTab() async {
    final activeIndex = _ref.read(activeTabIndexProvider);
    if (state.isEmpty || activeIndex < 0 || activeIndex >= state.length) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xsd'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      try {
        final content = await File(filePath).readAsString();
        final verbose = _ref.read(diagnosticsProvider);
        final parser = XsdParser(content, verbose: verbose);

        // Update session current schema so future tabs use it
        _currentXsdParser = parser;
        _currentXsdPath = filePath;

        // Update active tab
        final updated = [...state];
        final tab = updated[activeIndex];
        updated[activeIndex] = FileTabState(
          path: tab.path,
          treeStateProvider: tab.treeStateProvider,
          xsdParser: parser,
          xsdPath: filePath,
        );
        state = updated;
      } catch (e) {
        print('Error loading selected XSD: $e');
      }
    }
  }

  Future<void> openNewFile() async {
    print('DEBUG: openNewFile called');
    try {
      _ref.read(loadingStateProvider.notifier).state = true;
      print('DEBUG: Loading state set to true');

      // Load default XSD schema if not already loaded
      await _loadXsdSchema();
      print('DEBUG: XSD schema loading completed');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['arxml', 'xml'],
      );
      print('DEBUG: File picker result: ${result?.files.length ?? 0} files');

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        print('DEBUG: Selected file path: $filePath');

        final cache = _ref.read(astCacheProvider);
        List<ElementNode>? nodes = cache.get(filePath);
        String fileContent;
        if (nodes == null) {
          fileContent = await File(filePath).readAsString();
          print('DEBUG: File content loaded, length: ${fileContent.length}');
          // Try auto-detect schema for this file
          final detectedSchema = await _detectSchemaPathFromArxml(fileContent);
          XsdParser? xsdForTab = _currentXsdParser;
          String? xsdPath = _currentXsdPath;
          if (detectedSchema != null) {
            try {
              final content = await File(detectedSchema).readAsString();
              xsdForTab =
                  XsdParser(content, verbose: _ref.read(diagnosticsProvider));
              xsdPath = detectedSchema;
            } catch (e) {
              print('Warning: auto-detected XSD failed to load: $e');
            }
          }

          nodes = _arxmlLoader.parseXmlContent(fileContent);
          cache.put(filePath, nodes);
          print('DEBUG: XML parsed, nodes count: ${nodes.length}');

          final newTab = FileTabState(
            path: filePath,
            treeStateProvider: arxmlTreeStateProvider(nodes),
            xsdParser: xsdForTab,
            xsdPath: xsdPath,
          );

          state = [...state, newTab];
          _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
          print('DEBUG: New tab added, total tabs: ${state.length}');
          print('DEBUG: Active tab index set to: ${state.length - 1}');

          // Give a small delay to ensure state propagation
          await Future.delayed(const Duration(milliseconds: 100));
          print('DEBUG: State propagation complete');
        } else {
          print('DEBUG: Using cached AST for $filePath');
          final newTab = FileTabState(
            path: filePath,
            treeStateProvider: arxmlTreeStateProvider(nodes),
            xsdParser: _currentXsdParser,
            xsdPath: _currentXsdPath,
          );
          state = [...state, newTab];
          _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
        }
      } else {
        print('DEBUG: File picker cancelled or no file selected');
      }
    } catch (e, stackTrace) {
      print('ERROR in openNewFile: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _ref.read(loadingStateProvider.notifier).state = false;
      print('DEBUG: Loading state set to false');
    }
  }

  Future<void> createNewFile() async {
    // Load default XSD schema if not already loaded
    await _loadXsdSchema();

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select where to save the new file:',
      fileName: 'new_file.arxml',
    );

    if (outputFile != null) {
      const String defaultContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR>
</AUTOSAR>
''';
      await File(outputFile).writeAsString(defaultContent);
      // Now open the newly created file
      final fileContent = await File(outputFile).readAsString();

      // Try auto-detect schema
      final detectedSchema = await _detectSchemaPathFromArxml(fileContent);
      XsdParser? xsdForTab = _currentXsdParser;
      String? xsdPath = _currentXsdPath;
      if (detectedSchema != null) {
        try {
          final content = await File(detectedSchema).readAsString();
          xsdForTab =
              XsdParser(content, verbose: _ref.read(diagnosticsProvider));
          xsdPath = detectedSchema;
        } catch (e) {
          print('Warning: auto-detected XSD failed to load: $e');
        }
      }

      final nodes = _arxmlLoader.parseXmlContent(fileContent);
      final newTab = FileTabState(
        path: outputFile,
        treeStateProvider: arxmlTreeStateProvider(nodes),
        xsdParser: xsdForTab,
        xsdPath: xsdPath,
      );
      state = [...state, newTab];
      _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
    }
  }

  Future<void> saveActiveFile() async {
    final activeTab = _ref.read(activeTabProvider);
    if (activeTab == null) return;

    final treeState = _ref.read(activeTab.treeStateProvider);
    final xmlString = _arxmlLoader.toXmlString(treeState.rootNodes);
    await File(activeTab.path).writeAsString(xmlString);
  }

  void closeFile(int index) {
    final newTabs = List.of(state)..removeAt(index);
    if (newTabs.isEmpty) {
      _ref.read(activeTabIndexProvider.notifier).state = 0;
    } else {
      final newActiveIndex =
          (_ref.read(activeTabIndexProvider) - 1).clamp(0, newTabs.length - 1);
      _ref.read(activeTabIndexProvider.notifier).state = newActiveIndex;
    }
    state = newTabs;
  }

  Future<void> openFileAndNavigate(String filePath,
      {required List<String> shortNamePath}) async {
    // If already open, just navigate
    final existingIndex = state.indexWhere((t) => t.path == filePath);
    if (existingIndex != -1) {
      _ref.read(activeTabIndexProvider.notifier).state = existingIndex;
      _navigateToShortPath(state[existingIndex], shortNamePath);
      return;
    }

    try {
      _ref.read(loadingStateProvider.notifier).state = true;
      // Load default schema if missing
      await _loadXsdSchema();

      final cache = _ref.read(astCacheProvider);
      List<ElementNode>? nodes = cache.get(filePath);
      String? content;
      if (nodes == null) {
        content = await File(filePath).readAsString();
        nodes = _arxmlLoader.parseXmlContent(content);
        cache.put(filePath, nodes);
      }

      // Per-file auto-detect schema
      XsdParser? xsdForTab = _currentXsdParser;
      String? xsdPath = _currentXsdPath;
      final detectedSchema = content != null
          ? await _detectSchemaPathFromArxml(content)
          : null;
      if (detectedSchema != null) {
        try {
          final xsdContent = await File(detectedSchema).readAsString();
          xsdForTab =
              XsdParser(xsdContent, verbose: _ref.read(diagnosticsProvider));
          xsdPath = detectedSchema;
        } catch (_) {}
      }

      final tab = FileTabState(
        path: filePath,
        treeStateProvider: arxmlTreeStateProvider(nodes!),
        xsdParser: xsdForTab,
        xsdPath: xsdPath,
      );
      state = [...state, tab];
      final idx = state.length - 1;
      _ref.read(activeTabIndexProvider.notifier).state = idx;

      // Wait a moment for providers to wire
      await Future.delayed(const Duration(milliseconds: 50));
      _navigateToShortPath(tab, shortNamePath);
    } finally {
      _ref.read(loadingStateProvider.notifier).state = false;
    }
  }

  void _navigateToShortPath(FileTabState tab, List<String> shortNamePath) {
    final tree = _ref.read(tab.treeStateProvider);
    // Traverse visible nodes to find path by successive short-name matches
    int? targetId;
    void search(ElementNode node, List<String> remaining) {
      if (remaining.isEmpty) {
        targetId = node.id;
        return;
      }
      final next = remaining.first;
      for (final c in node.children) {
        final hasShort =
            c.children.isNotEmpty && c.children.first.children.isEmpty;
        final value = hasShort ? c.children.first.elementText : '';
        if (c.elementText == 'SHORT-NAME' || value == next) {
          // If this node is a SHORT-NAME container or matches value, continue
          if (c.elementText != 'SHORT-NAME') {
            search(c, remaining.sublist(1));
          } else if (c.parent != null) {
            search(c.parent!, remaining.sublist(1));
          }
          if (targetId != null) return;
        } else {
          search(c, remaining);
          if (targetId != null) return;
        }
      }
    }

    for (final r in tree.rootNodes) {
      if (targetId != null) break;
      search(r, shortNamePath);
    }

    if (targetId != null) {
      final notifier = _ref.read(tab.treeStateProvider.notifier);
      notifier.expandUntilNode(targetId!);
      final updated = _ref.read(tab.treeStateProvider);
      final index = updated.visibleNodes.indexWhere((n) => n.id == targetId);
      if (index != -1) {
        // Request UI to scroll now that we know the index
        _ref.read(scrollToIndexProvider.notifier).state = index;
      }
    }
  }

  // Mark the tab that owns the given tree provider as dirty (unsaved changes)
  void markDirtyForTreeProvider(
      AutoDisposeStateNotifierProvider<ArxmlTreeStateNotifier, ArxmlTreeState>
          provider) {
    final idx = state.indexWhere((t) => t.treeStateProvider == provider);
    if (idx == -1) return;
    final updated = List<FileTabState>.from(state);
    updated[idx] = updated[idx].copyWith(isDirty: true);
    state = updated;
  }
}

// Main App
void main() {
  runApp(const ProviderScope(child: XmlExplorerApp()));
}

class XmlExplorerApp extends StatelessWidget {
  const XmlExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Subtle palette inspired by T&S look & feel
    const primary = Color(0xFF0D2A4A); // deep blue
    const primaryContainer = Color(0xFF16406F); // lighter blue for gradients
    const secondary = Color(0xFF00C2C7); // cyan accent
    const secondaryContainer = Color(0xFF6FE4E7);
    const background = Color(0xFFF7F9FC); // soft light background

    final colorScheme = const ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      secondary: secondary,
      onSecondary: Color(0xFF062238),
      secondaryContainer: secondaryContainer,
      background: background,
      onBackground: primary,
      surface: Colors.white,
      onSurface: primary,
    );

    return MaterialApp(
      title: 'ARXML Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: primary.withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(color: Colors.white),
        ),
      ),
      home: const MyHomePage(title: 'ARXML Explorer'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // Use the ambient ProviderScope from the app; do not create a nested scope
    return const _InnerHomePageWrapper();
  }
}

class _InnerHomePageWrapper extends StatelessWidget {
  const _InnerHomePageWrapper();

  @override
  Widget build(BuildContext context) {
    return const _InnerHomePage(title: 'ARXML Explorer');
  }
}

class _InnerHomePage extends ConsumerStatefulWidget {
  final String title;
  const _InnerHomePage({required this.title});

  @override
  ConsumerState<_InnerHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<_InnerHomePage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  void _syncTabController(List<FileTabState> tabs, int activeTabIndex) {
    print(
        'DEBUG: _updateTabController - tabs.length: ${tabs.length}, activeTabIndex: $activeTabIndex');

    if (_tabController == null || _tabController!.length != tabs.length) {
      print('DEBUG: Creating new TabController');
      _tabController?.dispose();
      if (tabs.isNotEmpty) {
        final safeActiveIndex = activeTabIndex.clamp(0, tabs.length - 1);
        print('DEBUG: SafeActiveIndex: $safeActiveIndex');
        _tabController = TabController(
            length: tabs.length, vsync: this, initialIndex: safeActiveIndex);

        _tabController!.addListener(() {
          if (_tabController != null && !_tabController!.indexIsChanging) {
            ref.read(activeTabIndexProvider.notifier).state =
                _tabController!.index;
          }
        });
        print('DEBUG: TabController created successfully');
      } else {
        _tabController = null;
        print('DEBUG: TabController set to null (no tabs)');
      }
    } else if (_tabController != null) {
      final safeActiveIndex = activeTabIndex.clamp(0, tabs.length - 1);
      print('DEBUG: Updating existing TabController index to: $safeActiveIndex');
      if (_tabController!.index != safeActiveIndex) {
        _tabController!.animateTo(safeActiveIndex);
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
    final workspaceIndex = ref.watch(workspaceIndexProvider);

    // Keep TabController in sync with providers
    _syncTabController(tabs, activeIndex);

    final activeTreeState =
        activeTab != null ? ref.watch(activeTab.treeStateProvider) : null;

    // Consume any pending scroll request (from go-to-definition)
    final pendingScrollIndex = ref.watch(scrollToIndexProvider);
    if (pendingScrollIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        itemScrollController.scrollTo(
          index: pendingScrollIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        ref.read(scrollToIndexProvider.notifier).state = null;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Workspace (index only, no tabs)',
            onPressed: () => ref
                .read(workspaceIndexProvider.notifier)
                .pickAndIndexWorkspace(),
          ),
          IconButton(
              icon: const Icon(Icons.save), onPressed: notifier.saveActiveFile),
          IconButton(
            icon: const Icon(Icons.file_present),
            tooltip: 'Select XSD schema for active tab',
            onPressed: notifier.pickXsdForActiveTab,
          ),
          IconButton(
            icon: Icon(
              diagnosticsOn ? Icons.bug_report : Icons.bug_report_outlined,
              color: diagnosticsOn
                  ? Theme.of(context).colorScheme.secondary
                  : Colors.white,
            ),
            tooltip: diagnosticsOn
                ? 'Verbose XSD diagnostics: ON'
                : 'Verbose XSD diagnostics: OFF',
            onPressed: () {
              // toggle provider and rebuild parsers with verbose
              ref.read(fileTabsProvider.notifier).toggleDiagnostics();
            },
          ),
          IconButton(
            icon: Icon(
              liveValidationOn
                  ? Icons.health_and_safety
                  : Icons.health_and_safety_outlined,
              color: liveValidationOn
                  ? Theme.of(context).colorScheme.secondary
                  : Colors.white,
            ),
            tooltip: liveValidationOn
                ? 'Live validation: ON'
                : 'Live validation: OFF',
            onPressed: () {
              final next = !ref.read(liveValidationProvider);
              ref.read(liveValidationProvider.notifier).state = next;
              if (next) {
                // Trigger an initial validation when enabling
                ref.read(validationSchedulerProvider.notifier).schedule(
                      delay: const Duration(milliseconds: 100),
                    );
              }
            },
          ),
          if (activeTab != null && activeTab.xsdParser != null)
            IconButton(
              icon: const Icon(Icons.rule),
              tooltip: 'Validate current document against XSD',
              onPressed: () async {
                final tree = ref.read(activeTab.treeStateProvider);
                final parser = activeTab.xsdParser!;
                final validator = const ArxmlValidator();
                final issues = validator.validate(tree.rootNodes, parser);
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
                          child: const Text('Close')),
                    ],
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (activeTreeState != null) {
                showSearch(
                  context: context,
                  delegate: CustomSearchDelegate(activeTreeState),
                ).then((nodeId) {
                  if (nodeId != null && activeTab != null) {
                    final treeNotifier =
                        ref.read(activeTab.treeStateProvider.notifier);
                    treeNotifier.expandUntilNode(nodeId);
                    final treeState = ref.read(activeTab.treeStateProvider);
                    final index = treeState.visibleNodes
                        .indexWhere((n) => n.id == nodeId);
                    if (index != -1) {
                      itemScrollController.scrollTo(
                        index: index,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.unfold_less),
            onPressed: () {
              if (activeTab != null) {
                ref.read(activeTab.treeStateProvider.notifier).collapseAll();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.unfold_more),
            onPressed: () {
              if (activeTab != null) {
                ref.read(activeTab.treeStateProvider.notifier).expandAll();
              }
            },
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
                              child: Row(
                                children: [
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
                                    child: Row(
                                      children: [
                                        Text(
                                          tab.path
                                              .split(Platform.pathSeparator)
                                              .last,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: _tabController != null &&
                                                    tabs.indexOf(tab) ==
                                                        _tabController!.index
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
                ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeTab != null && _tabController != null
              ? Column(
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
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)))
                                .toList(),
                          ),
                        ),
                      ),
                    if (workspaceIndex.indexing)
                      LinearProgressIndicator(
                        minHeight: 2,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    if (workspaceIndex.rootDir != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.folder,
                                size: 16, color: Colors.white70),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${workspaceIndex.rootDir} — files: ${workspaceIndex.filesIndexed}${workspaceIndex.lastScan != null ? ' — last: ${workspaceIndex.lastScan}' : ''}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => ref
                                  .read(workspaceIndexProvider.notifier)
                                  .refresh(),
                              icon: const Icon(Icons.refresh,
                                  size: 14, color: Colors.white70),
                              label: const Text('Refresh',
                                  style: TextStyle(color: Colors.white70)),
                            )
                          ],
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController!,
                        children: tabs.map((tab) {
                          return Consumer(builder: (context, ref, child) {
                            final treeState = ref.watch(tab.treeStateProvider);
                            return ScrollablePositionedList.builder(
                              itemScrollController: itemScrollController,
                              itemPositionsListener: itemPositionsListener,
                              itemCount: treeState.visibleNodes.length,
                              itemBuilder: (context, index) {
                                final node = treeState.visibleNodes[index];
                                return ElementNodeWidget(
                                  node: node,
                                  xsdParser: tab.xsdParser,
                                  key: ValueKey(node.id),
                                  treeStateProvider: tab.treeStateProvider,
                                );
                              },
                            );
                          });
                        }).toList(),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: Text("Open a file to begin"),
                ),
    );
  }
}
