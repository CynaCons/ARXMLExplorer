import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'elementnodewidget.dart';
import 'arxmlloader.dart';
import 'elementnodesearchdelegate.dart';

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

        final fileContent = await File(filePath).readAsString();
        print('DEBUG: File content loaded, length: ${fileContent.length}');

        final nodes = _arxmlLoader.parseXmlContent(fileContent);
        print('DEBUG: XML parsed, nodes count: ${nodes.length}');

        final newTab = FileTabState(
          path: filePath,
          treeStateProvider: arxmlTreeStateProvider(nodes),
          xsdParser: _currentXsdParser,
          xsdPath: _currentXsdPath,
        );

        state = [...state, newTab];
        _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
        print('DEBUG: New tab added, total tabs: ${state.length}');
        print('DEBUG: Active tab index set to: ${state.length - 1}');

        // Give a small delay to ensure state propagation
        await Future.delayed(const Duration(milliseconds: 100));
        print('DEBUG: State propagation complete');
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
      final nodes = _arxmlLoader.parseXmlContent(fileContent);
      final newTab = FileTabState(
        path: outputFile,
        treeStateProvider: arxmlTreeStateProvider(nodes),
        xsdParser: _currentXsdParser,
        xsdPath: _currentXsdPath,
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

class MyHomePage extends ConsumerStatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTabController();
  }

  void _updateTabController() {
    final tabs = ref.watch(fileTabsProvider);
    final activeTabIndex = ref.watch(activeTabIndexProvider);

    print(
        'DEBUG: _updateTabController - tabs.length: ${tabs.length}, activeTabIndex: $activeTabIndex');

    // Only recreate TabController if the length actually changed or it's null
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
      // Just update the index if TabController already exists and has correct length
      final safeActiveIndex = activeTabIndex.clamp(0, tabs.length - 1);
      print(
          'DEBUG: Updating existing TabController index to: $safeActiveIndex');
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
    final activeTab = ref.watch(activeTabProvider);
    final notifier = ref.read(fileTabsProvider.notifier);
    final isLoading = ref.watch(loadingStateProvider);
    final diagnosticsOn = ref.watch(diagnosticsProvider);
    final activeTreeState =
        activeTab != null ? ref.watch(activeTab.treeStateProvider) : null;

    // Update TabController only when tabs change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTabController();
    });

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
              ref.read(diagnosticsProvider.notifier).state = !diagnosticsOn;
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
        bottom: tabs.isEmpty || _tabController == null
            ? null
            : TabBar(
                controller: _tabController!,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: tabs
                    .map((tab) => Tab(
                          child: Row(
                            children: [
                              Text(
                                tab.path.split(Platform.pathSeparator).last,
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (tab.xsdPath != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Tooltip(
                                    message: 'Schema: ${tab.xsdPath}',
                                    child: const Icon(Icons.schema,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.white70),
                                onPressed: () =>
                                    notifier.closeFile(tabs.indexOf(tab)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeTab != null && _tabController != null
              ? TabBarView(
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
                )
              : const Center(
                  child: Text("Open a file to begin"),
                ),
    );
  }
}
