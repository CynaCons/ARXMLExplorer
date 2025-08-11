import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;

import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'package:arxml_explorer/arxml_validator.dart';
import 'elementnodewidget.dart';
import 'arxmlloader.dart';
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
    final opts = ref.read(validationOptionsProvider);
    final issues = validator.validate(tree.rootNodes, parser, options: opts);
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

// NEW: Validation filter text
final validationFilterProvider = StateProvider<String>((ref) => '');

// NEW: NavigationRail selected index (0=Editor, 1=Workspace, 2=Validation, 3=Settings)
final navRailIndexProvider = StateProvider<int>((ref) => 0);

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
    final header = content.split(RegExp(r'\r?\n')).take(100).join(' ');

    // Helper: try candidates (filenames or paths) in bundled xsd then workspace
    Future<String?> _resolveCandidates(List<String> candidates) async {
      // 1) Check absolute/relative path directly if exists
      for (final c in candidates) {
        try {
          final pathGuess = c;
          if (await File(pathGuess).exists()) return pathGuess;
        } catch (_) {}
      }
      // 2) Check bundled lib/res/xsd by basename
      for (final c in candidates) {
        final base = c.split(RegExp(r'[\\\/]')).last;
        final bundled = 'lib/res/xsd/' + base;
        if (await File(bundled).exists()) return bundled;
      }
      // 3) Search workspace folder recursively by basename
      final wsRoot = _ref.read(workspaceIndexProvider).rootDir;
      if (wsRoot != null) {
        for (final c in candidates) {
          final base = c.split(RegExp(r'[\\\/]')).last;
          final hit = await _findInWorkspace(wsRoot, base);
          if (hit != null) return hit;
        }
      }
      return null;
    }

    // Parse xsi:schemaLocation (pairs: namespace URI followed by URL/path)
    final schemaLocAttr = RegExp(r'xsi:schemaLocation\s*=\s*"([^"]+)"')
        .firstMatch(header)
        ?.group(1);
    if (schemaLocAttr != null) {
      final tokens = schemaLocAttr
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      final urls = <String>[];
      for (var i = 0; i < tokens.length; i++) {
        // take every second token as a location if present
        if (i % 2 == 1) {
          var u = tokens[i];
          // strip URI scheme and fragments
          final scheme = u.indexOf('://');
          if (scheme > 0) u = u.substring(scheme + 3);
          final hash = u.indexOf('#');
          if (hash >= 0) u = u.substring(0, hash);
          final q = u.indexOf('?');
          if (q >= 0) u = u.substring(0, q);
          urls.add(u);
        }
      }
      final resolved = await _resolveCandidates(urls);
      if (resolved != null) return resolved;
    }

    // Parse noNamespace schema location
    final noNsAttr = RegExp(r'noNamespaceSchemaLocation\s*=\s*"([^"]+)"')
        .firstMatch(header)
        ?.group(1);
    if (noNsAttr != null) {
      final resolved = await _resolveCandidates([noNsAttr]);
      if (resolved != null) return resolved;
    }

    // Version hint on AUTOSAR root
    final versionMatch =
        RegExp(r'AUTOSAR[^>]*version\s*=\s*"([^"]+)"').firstMatch(header);
    if (versionMatch != null) {
      final ver = versionMatch.group(1)!.trim();
      final variants = <String>[
        'AUTOSAR_$ver.xsd',
        'AUTOSAR_${ver.replaceAll('.', '-')}.xsd',
        'AUTOSAR_${ver.replaceAll('-', '.')}.xsd',
      ];
      final resolved = await _resolveCandidates(variants);
      if (resolved != null) return resolved;
    }

    // Fallback to default bundled
    final fallback = 'lib/res/xsd/AUTOSAR_00050.xsd';
    return await File(fallback).exists() ? fallback : null;
  }

  // Search workspace folder recursively for a filename
  Future<String?> _findInWorkspace(String rootDir, String basename) async {
    try {
      final dir = Directory(rootDir);
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is File &&
            ent.path.split(Platform.pathSeparator).last == basename) {
          return ent.path;
        }
      }
    } catch (_) {}
    return null;
  }

  // Load the XSD schema for the active tab from file picker
  Future<void> pickXsdForActiveTab() async {
    final activeIndex = _ref.read(activeTabIndexProvider);
    if (state.isEmpty || activeIndex < 0 || activeIndex >= state.length) return;

    fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.custom,
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

      fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
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

    String? outputFile = await fp.FilePicker.platform.saveFile(
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
    // Clear dirty flag for the saved tab
    final idx = state.indexWhere((t) => t.path == activeTab.path);
    if (idx != -1) {
      final updated = List<FileTabState>.from(state);
      updated[idx] = updated[idx].copyWith(isDirty: false);
      state = updated;
    }
  }

  Future<void> saveAllFiles() async {
    for (var i = 0; i < state.length; i++) {
      final tab = state[i];
      final treeState = _ref.read(tab.treeStateProvider);
      final xmlString = _arxmlLoader.toXmlString(treeState.rootNodes);
      await File(tab.path).writeAsString(xmlString);
    }
    // Clear all dirty flags
    state = [for (final t in state) t.copyWith(isDirty: false)];
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
      final detectedSchema =
          content != null ? await _detectSchemaPathFromArxml(content) : null;
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
        treeStateProvider: arxmlTreeStateProvider(nodes),
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

  Future<void> resetXsdForActiveTabToSession() async {
    // Ensure session schema is loaded
    await _loadXsdSchema();
    final activeIndex = _ref.read(activeTabIndexProvider);
    if (state.isEmpty || activeIndex < 0 || activeIndex >= state.length) return;
    final updated = [...state];
    final tab = updated[activeIndex];
    updated[activeIndex] = FileTabState(
      path: tab.path,
      treeStateProvider: tab.treeStateProvider,
      xsdParser: _currentXsdParser,
      xsdPath: _currentXsdPath,
      isDirty: tab.isDirty,
    );
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
  bool _workspaceDragOver = false; // drag-highlight state for Workspace view

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
    final activeIndex = ref.watch(activeTabIndexProvider);
    final activeTab = ref.watch(activeTabProvider);
    final notifier = ref.read(fileTabsProvider.notifier);
    final isLoading = ref.watch(loadingStateProvider);
    final diagnosticsOn = ref.watch(diagnosticsProvider);
    final liveValidationOn = ref.watch(liveValidationProvider);
    final workspaceIndex = ref.watch(workspaceIndexProvider);
    final navIndex = ref.watch(navRailIndexProvider);
    final issues = ref.watch(validationIssuesProvider);

    // Keep TabController in sync with providers
    _syncTabController(tabs, activeIndex);

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
            icon: const Icon(Icons.save_alt),
            tooltip: 'Save All',
            onPressed: notifier.saveAllFiles,
          ),
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
              onPressed: () => notifier.resetXsdForActiveTabToSession(),
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Use session XSD'),
            ),
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
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          // Validation count + quick switch
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
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          issues.length > 99 ? '99+' : '${issues.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                                            fontWeight: _tabController !=
                                                        null &&
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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navIndex,
            onDestinationSelected: (i) =>
                ref.read(navRailIndexProvider.notifier).state = i,
            labelType: NavigationRailLabelType.selected,
            useIndicator: true,
            indicatorShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('Editor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('Workspace'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.rule_outlined),
                selectedIcon: Icon(Icons.rule),
                label: Text('Validation'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Builder(
              builder: (context) {
                if (navIndex == 1) {
                  // Workspace View with desktop drag-and-drop
                  final files = workspaceIndex.targets.values
                      .expand((list) => list.map((t) => t.filePath))
                      .toSet()
                      .toList()
                    ..sort();
                  if (workspaceIndex.rootDir == null) {
                    return Center(
                      child: TextButton.icon(
                        onPressed: () => ref
                            .read(workspaceIndexProvider.notifier)
                            .pickAndIndexWorkspace(),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open Workspace'),
                      ),
                    );
                  }
                  return DropTarget(
                    onDragEntered: (_) =>
                        setState(() => _workspaceDragOver = true),
                    onDragExited: (_) =>
                        setState(() => _workspaceDragOver = false),
                    onDragDone: (details) async {
                      setState(() => _workspaceDragOver = false);
                      final dropped = details.files
                          .map((f) => f.path)
                          .whereType<String>()
                          .toList();
                      if (dropped.isEmpty) return;

                      bool isArxml(String path) {
                        final ext = path.toLowerCase();
                        return ext.endsWith('.arxml') || ext.endsWith('.xml');
                      }

                      Future<List<String>> collectArxml(String dir) async {
                        final out = <String>[];
                        try {
                          final directory = Directory(dir);
                          if (!directory.existsSync()) return out;
                          await for (final ent in directory.list(
                              recursive: true, followLinks: false)) {
                            if (ent is File && isArxml(ent.path))
                              out.add(ent.path);
                          }
                        } catch (_) {}
                        return out;
                      }

                      final dirs = <String>[];
                      final filePaths = <String>[];
                      for (final pth in dropped) {
                        final t =
                            FileSystemEntity.typeSync(pth, followLinks: false);
                        if (t == FileSystemEntityType.directory) {
                          dirs.add(pth);
                        } else if (t == FileSystemEntityType.file) {
                          if (isArxml(pth)) filePaths.add(pth);
                        }
                      }

                      final idxNotifier =
                          ref.read(workspaceIndexProvider.notifier);
                      final root = ref.read(workspaceIndexProvider).rootDir;

                      if (dirs.isNotEmpty) {
                        if (root == null) {
                          // Set workspace to first dropped folder
                          await idxNotifier.indexFolder(dirs.first);
                          // Add extras from remaining folders/files
                          final extras = <String>[];
                          for (int i = 1; i < dirs.length; i++) {
                            extras.addAll(await collectArxml(dirs[i]));
                          }
                          extras.addAll(filePaths);
                          if (extras.isNotEmpty)
                            await idxNotifier.addFiles(extras);
                        } else {
                          final toAdd = <String>[];
                          for (final d in dirs) {
                            toAdd.addAll(await collectArxml(d));
                          }
                          toAdd.addAll(filePaths);
                          if (toAdd.isNotEmpty)
                            await idxNotifier.addFiles(toAdd);
                        }
                      } else {
                        // Only files were dropped
                        if (root == null) {
                          final commonDir = p.dirname(filePaths.first);
                          await idxNotifier.indexFolder(commonDir);
                          // Optionally add specific files; indexFolder already covers commonDir
                        } else {
                          await idxNotifier.addFiles(filePaths);
                        }
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Added ${dirs.length} folder(s), ${filePaths.length} file(s) to index'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Stack(
                      children: [
                        // Existing Workspace column content
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (workspaceIndex.indexing)
                              LinearProgressIndicator(
                                minHeight: 4,
                                value: workspaceIndex.progress == 0
                                    ? null
                                    : workspaceIndex.progress,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.folder, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${workspaceIndex.rootDir} — files: ${workspaceIndex.filesIndexed}${workspaceIndex.lastScan != null ? ' — last: ${workspaceIndex.lastScan}' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => ref
                                        .read(workspaceIndexProvider.notifier)
                                        .refresh(),
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Refresh'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final res = await fp.FilePicker.platform
                                          .pickFiles(
                                              allowMultiple: true,
                                              type: fp.FileType.custom,
                                              allowedExtensions: [
                                            'arxml',
                                            'xml'
                                          ]);
                                      if (res != null) {
                                        final paths = res.files
                                            .where((f) => f.path != null)
                                            .map((f) => f.path!)
                                            .toList();
                                        await ref
                                            .read(
                                                workspaceIndexProvider.notifier)
                                            .addFiles(paths);
                                      }
                                    },
                                    icon: const Icon(Icons.add, size: 14),
                                    label: const Text('Add files'),
                                  ),
                                ],
                              ),
                            ),
                            if (workspaceIndex.fileStatus.isNotEmpty)
                              Expanded(
                                child: ListView(
                                  children: workspaceIndex.fileStatus.entries
                                      .map((e) {
                                    final st = e.value;
                                    IconData icon;
                                    Color color;
                                    switch (st) {
                                      case IndexStatus.queued:
                                        icon = Icons.schedule;
                                        color = Colors.grey;
                                        break;
                                      case IndexStatus.processing:
                                        icon = Icons.hourglass_top;
                                        color = Colors.amber;
                                        break;
                                      case IndexStatus.processed:
                                        icon = Icons.check_circle_outline;
                                        color = Colors.green;
                                        break;
                                      case IndexStatus.error:
                                        icon = Icons.error_outline;
                                        color = Colors.redAccent;
                                        break;
                                    }
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(icon, color: color),
                                      title: Text(e.key
                                          .split(Platform.pathSeparator)
                                          .last),
                                      subtitle: Text(e.key,
                                          overflow: TextOverflow.ellipsis),
                                      trailing: Text(st.name),
                                    );
                                  }).toList(),
                                ),
                              )
                            else
                              const Divider(height: 1),
                            Expanded(
                              child: files.isEmpty
                                  ? const Center(
                                      child: Text(
                                          'No ARXML files indexed yet\nDrag and drop files/folders here',
                                          textAlign: TextAlign.center),
                                    )
                                  : ListView.builder(
                                      itemCount: files.length,
                                      itemBuilder: (context, i) {
                                        final fp = files[i];
                                        return ListTile(
                                          dense: true,
                                          title: Text(fp
                                              .split(Platform.pathSeparator)
                                              .last),
                                          subtitle: Text(fp,
                                              overflow: TextOverflow.ellipsis),
                                          leading:
                                              const Icon(Icons.description),
                                          onTap: () => ref
                                              .read(fileTabsProvider.notifier)
                                              .openFileAndNavigate(fp,
                                                  shortNamePath: const []),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                        if (_workspaceDragOver)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.08),
                                  border: Border.all(
                                      color: Colors.blueAccent.withOpacity(0.7),
                                      width: 2),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.file_download,
                                          size: 36, color: Colors.blueAccent),
                                      SizedBox(height: 8),
                                      Text('Drop files or folders to index',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blueAccent)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                } else if (navIndex == 2) {
                  // Validation View
                  final issues = ref.watch(validationIssuesProvider);
                  final filter = ref.watch(validationFilterProvider);
                  final selectedSeverities = ref.watch(severityFiltersProvider);
                  final filtered = (filter.trim().isEmpty
                          ? issues
                          : issues
                              .where((i) =>
                                  i.message
                                      .toLowerCase()
                                      .contains(filter.toLowerCase()) ||
                                  i.path
                                      .toLowerCase()
                                      .contains(filter.toLowerCase()))
                              .toList())
                      .where((i) => selectedSeverities.contains(i.severity))
                      .toList();
                  if (issues.isEmpty) {
                    return const Center(
                        child: Text('No validation issues to display'));
                  }
                  final selectedIdx = ref.watch(selectedIssueIndexProvider);
                  return Stack(
                    children: [
                      FocusableActionDetector(
                        shortcuts: <LogicalKeySet, Intent>{
                          LogicalKeySet(LogicalKeyboardKey.arrowDown):
                              const NextFocusIntent(),
                          LogicalKeySet(LogicalKeyboardKey.arrowUp):
                              const PreviousFocusIntent(),
                          LogicalKeySet(LogicalKeyboardKey.keyN):
                              const NextFocusIntent(),
                          LogicalKeySet(LogicalKeyboardKey.keyP):
                              const PreviousFocusIntent(),
                        },
                        actions: <Type, Action<Intent>>{
                          NextFocusIntent: CallbackAction<NextFocusIntent>(
                            onInvoke: (intent) {
                              final next = ((selectedIdx ?? -1) + 1)
                                  .clamp(0, filtered.length - 1);
                              ref
                                  .read(selectedIssueIndexProvider.notifier)
                                  .state = next;
                              return null;
                            },
                          ),
                          PreviousFocusIntent:
                              CallbackAction<PreviousFocusIntent>(
                            onInvoke: (intent) {
                              final prev =
                                  ((selectedIdx ?? filtered.length) - 1)
                                      .clamp(0, filtered.length - 1);
                              ref
                                  .read(selectedIssueIndexProvider.notifier)
                                  .state = prev;
                              return null;
                            },
                          ),
                        },
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Filter issues by text or path',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) {
                                  ref
                                      .read(validationFilterProvider.notifier)
                                      .state = v;
                                  ref
                                      .read(selectedIssueIndexProvider.notifier)
                                      .state = null;
                                },
                              ),
                            ),
                            // Severity chips
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _severityChip(
                                      ref,
                                      'Errors',
                                      ValidationSeverity.error,
                                      Colors.redAccent),
                                  _severityChip(ref, 'Warnings',
                                      ValidationSeverity.warning, Colors.amber),
                                  _severityChip(
                                      ref,
                                      'Info',
                                      ValidationSeverity.info,
                                      Colors.blueAccent),
                                ],
                              ),
                            ),
                            if (selectedIdx != null &&
                                selectedIdx >= 0 &&
                                selectedIdx < filtered.length)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 6, 12, 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        filtered[selectedIdx].path,
                                        style: const TextStyle(
                                            fontFamily: 'monospace'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.copy, size: 14),
                                      label: const Text('Copy path'),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                            text: filtered[selectedIdx].path));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Path copied')),
                                        );
                                      },
                                    )
                                  ],
                                ),
                              ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final issue = filtered[i];
                                  final iconData =
                                      issue.severity == ValidationSeverity.error
                                          ? Icons.error_outline
                                          : issue.severity ==
                                                  ValidationSeverity.warning
                                              ? Icons.warning_amber_outlined
                                              : Icons.info_outline;
                                  final iconColor =
                                      issue.severity == ValidationSeverity.error
                                          ? Colors.redAccent
                                          : issue.severity ==
                                                  ValidationSeverity.warning
                                              ? Colors.amber
                                              : Colors.blueAccent;
                                  final selected = i == selectedIdx;
                                  return ListTile(
                                    selected: selected,
                                    selectedTileColor: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                        .withOpacity(0.2),
                                    leading: Icon(iconData, color: iconColor),
                                    title: Text(issue.message),
                                    subtitle: Text(issue.path),
                                    onTap: () {
                                      ref
                                          .read(selectedIssueIndexProvider
                                              .notifier)
                                          .state = i;
                                      // Navigate to the selected issue's path
                                      final tab = ref.read(activeTabProvider);
                                      if (tab == null) return;
                                      final parts = issue.path
                                          .split('/')
                                          .where((e) => e.isNotEmpty)
                                          .toList();
                                      int? targetId;
                                      void search(ElementNode node, int idx) {
                                        if (idx >= parts.length) {
                                          targetId = node.id;
                                          return;
                                        }
                                        for (final c in node.children) {
                                          if (c.elementText == parts[idx]) {
                                            search(c, idx + 1);
                                            if (targetId != null) return;
                                          } else {
                                            search(c, idx);
                                            if (targetId != null) return;
                                          }
                                        }
                                      }

                                      final tree =
                                          ref.read(tab.treeStateProvider);
                                      for (final r in tree.rootNodes) {
                                        if (targetId != null) break;
                                        if (parts.isEmpty ||
                                            r.elementText == parts.first) {
                                          search(r, parts.isEmpty ? 0 : 1);
                                        }
                                      }
                                      if (targetId != null) {
                                        final notifier = ref.read(
                                            tab.treeStateProvider.notifier);
                                        notifier.expandUntilNode(targetId!);
                                        final updated =
                                            ref.read(tab.treeStateProvider);
                                        final index = updated.visibleNodes
                                            .indexWhere(
                                                (n) => n.id == targetId);
                                        if (index != -1) {
                                          itemScrollController.scrollTo(
                                            index: index,
                                            duration: const Duration(
                                                milliseconds: 400),
                                            curve: Curves.easeInOut,
                                          );
                                          // switch to Editor view
                                          ref
                                              .read(
                                                  navRailIndexProvider.notifier)
                                              .state = 0;
                                        }
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right-side gutter with aggregate marks
                      Positioned(
                        right: 2,
                        top: 0,
                        bottom: 0,
                        width: 6,
                        child: _ValidationGutter(issues: filtered),
                      ),
                    ],
                  );
                } else if (navIndex == 3) {
                  // Settings View
                  final opts = ref.watch(validationOptionsProvider);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SwitchListTile(
                        title: const Text('Live validation'),
                        subtitle: const Text('Validate while editing'),
                        value: ref.watch(liveValidationProvider),
                        onChanged: (v) {
                          ref.read(liveValidationProvider.notifier).state = v;
                          if (v) {
                            ref
                                .read(validationSchedulerProvider.notifier)
                                .schedule(
                                    delay: const Duration(milliseconds: 100));
                          }
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Verbose XSD diagnostics'),
                        subtitle: const Text('Show parser resolution trace'),
                        value: ref.watch(diagnosticsProvider),
                        onChanged: (_) {
                          ref
                              .read(fileTabsProvider.notifier)
                              .toggleDiagnostics();
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Ignore ADMIN-DATA in validation'),
                        subtitle: const Text(
                            'Omit ADMIN-DATA subtree from validation results'),
                        value: opts.ignoreAdminData,
                        onChanged: (v) {
                          ref.read(validationOptionsProvider.notifier).state =
                              ValidationOptions(ignoreAdminData: v);
                          // re-run validation if live is on
                          ref
                              .read(validationSchedulerProvider.notifier)
                              .schedule(
                                delay: const Duration(milliseconds: 100),
                              );
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Show Resource HUD (bottom-right)'),
                        subtitle: const Text(
                            'Displays app memory and model size (debug estimates)'),
                        value: ref.watch(showResourceHudProvider),
                        onChanged: (v) => ref
                            .read(showResourceHudProvider.notifier)
                            .state = v,
                      ),
                    ],
                  );
                }

                // Editor View (default)
                return isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : activeTab != null && _tabController != null
                        ? Stack(
                            children: [
                              Column(
                                children: [
                                  if (diagnosticsOn &&
                                      activeTab.xsdParser != null)
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
                                                    color: Colors.white70,
                                                  )))
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        TabBar(
                                          controller: _tabController!,
                                          isScrollable: true,
                                          indicatorColor: Colors.transparent,
                                          tabs: tabs
                                              .map((tab) => Tab(
                                                    child: Row(
                                                      children: [
                                                        AnimatedContainer(
                                                          duration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      180),
                                                          curve: Curves
                                                              .easeOutCubic,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _tabController !=
                                                                        null &&
                                                                    tabs.indexOf(
                                                                            tab) ==
                                                                        _tabController!
                                                                            .index
                                                                ? Colors.white
                                                                    .withOpacity(
                                                                        0.15)
                                                                : Colors
                                                                    .transparent,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Text(
                                                                tab.path
                                                                    .split(Platform
                                                                        .pathSeparator)
                                                                    .last,
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight: _tabController !=
                                                                              null &&
                                                                          tabs.indexOf(tab) ==
                                                                              _tabController!
                                                                                  .index
                                                                      ? FontWeight
                                                                          .w700
                                                                      : FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                              if (tab.isDirty)
                                                                const Padding(
                                                                  padding: EdgeInsets
                                                                      .only(
                                                                          left:
                                                                              6.0),
                                                                  child:
                                                                      Tooltip(
                                                                    message:
                                                                        'Unsaved changes',
                                                                    child: Icon(
                                                                        Icons
                                                                            .circle,
                                                                        size: 8,
                                                                        color: Colors
                                                                            .amber),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (tab.xsdPath != null)
                                                          const Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                    left: 6.0),
                                                            child: Icon(
                                                                Icons.rule,
                                                                size: 14),
                                                          )
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                        Expanded(
                                          child: TabBarView(
                                            controller: _tabController!,
                                            children: tabs.map((tab) {
                                              return Consumer(builder:
                                                  (context, ref, child) {
                                                final treeState = ref.watch(
                                                    tab.treeStateProvider);
                                                return ScrollablePositionedList
                                                    .builder(
                                                  itemScrollController:
                                                      itemScrollController,
                                                  itemPositionsListener:
                                                      itemPositionsListener,
                                                  itemCount: treeState
                                                      .visibleNodes.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final node = treeState
                                                        .visibleNodes[index];
                                                    return ElementNodeWidget(
                                                      node: node,
                                                      xsdParser: tab.xsdParser,
                                                      key: ValueKey(node.id),
                                                      treeStateProvider:
                                                          tab.treeStateProvider,
                                                    );
                                                  },
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
                              // Resource HUD overlay
                              if (ref.watch(showResourceHudProvider))
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: _ResourceHud(
                                    modelNodeCount: (() {
                                      final tab = ref.watch(activeTabProvider);
                                      if (tab == null) return 0;
                                      final tree =
                                          ref.watch(tab.treeStateProvider);
                                      int count = 0;
                                      void walk(ElementNode n) {
                                        count++;
                                        for (final c in n.children) walk(c);
                                      }

                                      for (final r in tree.rootNodes) walk(r);
                                      return count;
                                    })(),
                                  ),
                                ),
                            ],
                          )
                        : const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build a selectable severity chip
  Widget _severityChip(
      WidgetRef ref, String label, ValidationSeverity sev, Color color) {
    final selected = ref.watch(severityFiltersProvider).contains(sev);
    return FilterChip(
      selected: selected,
      onSelected: (v) {
        final set = {...ref.read(severityFiltersProvider)};
        if (v) {
          set.add(sev);
        } else {
          set.remove(sev);
        }
        // Ensure at least one stays selected
        if (set.isEmpty) set.add(sev);
        ref.read(severityFiltersProvider.notifier).state = set;
      },
      label: Text(label),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(color: color),
    );
  }
}

class _ValidationGutter extends StatelessWidget {
  final List<ValidationIssue> issues;
  const _ValidationGutter({required this.issues});

  Color _colorFor(ValidationSeverity s) {
    switch (s) {
      case ValidationSeverity.error:
        return Colors.redAccent;
      case ValidationSeverity.warning:
        return Colors.amber;
      case ValidationSeverity.info:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      if (height <= 0) return const SizedBox.shrink();
      // Distribute markers along height using path depth as a heuristic
      final buckets = <double, List<ValidationIssue>>{};
      for (final i in issues) {
        final segs = i.path.split('/').where((e) => e.isNotEmpty).length;
        final y = (segs * 13) % height; // spread a bit
        buckets.putIfAbsent(y, () => []).add(i);
      }
      return CustomPaint(
        painter: _GutterPainter(buckets, _colorFor),
      );
    });
  }
}

class _GutterPainter extends CustomPainter {
  final Map<double, List<ValidationIssue>> buckets;
  final Color Function(ValidationSeverity) colorFor;
  _GutterPainter(this.buckets, this.colorFor);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()..strokeCap = StrokeCap.round;
    buckets.forEach((y, list) {
      // pick top severity color
      ValidationSeverity sev = ValidationSeverity.info;
      for (final i in list) {
        if (i.severity == ValidationSeverity.error) {
          sev = ValidationSeverity.error;
          break;
        }
        if (i.severity == ValidationSeverity.warning) {
          sev = ValidationSeverity.warning;
        }
      }
      paint.color = colorFor(sev);
      paint.strokeWidth = (1.5 + (list.length - 1) * 0.6).clamp(1.5, 6.0);
      final dy = y.clamp(0.0, size.height - 1.0);
      canvas.drawLine(Offset(0.0, dy), Offset(w, dy), paint);
    });
  }

  @override
  bool shouldRepaint(covariant _GutterPainter oldDelegate) {
    return oldDelegate.buckets != buckets;
  }
}

class _ResourceHud extends StatefulWidget {
  final int modelNodeCount;
  const _ResourceHud({required this.modelNodeCount});
  @override
  State<_ResourceHud> createState() => _ResourceHudState();
}

class _ResourceHudState extends State<_ResourceHud> {
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
    // Use platformDispatcher to get basic info when available; fallback graceful
    try {
      final info = WidgetsBinding.instance.platformDispatcher;
      final estimates = <String>[];
      if (info.views.isNotEmpty) {
        // Add a simple marker to show activity
        estimates.add('views:${info.views.length}');
      }
      setState(() {
        _mem =
            'mem: ~N/A  |  nodes: ${widget.modelNodeCount}  |  ${estimates.join(' ')}';
      });
    } catch (_) {
      setState(() {
        _mem = 'nodes: ${widget.modelNodeCount}';
      });
    }
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
