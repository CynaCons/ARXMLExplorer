import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../editor.dart'; // For ARXMLTreeViewState
import 'package:arxml_explorer/core/xsd/xsd_parser/parser.dart';
import 'package:arxml_explorer/core/validation/issues.dart';
import 'package:arxml_explorer/app_providers.dart';
import '../../workspace/workspace.dart'; // For WorkspaceIndexNotifier
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/core/models/element_node.dart';
import 'dart:async';
import 'dart:io';
import 'dart:developer' show log;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:arxml_explorer/features/xsd/state/xsd_catalog.dart';

// Removed obsolete placeholder comment after migration.

final fileTabsProvider =
    StateNotifierProvider<FileTabsNotifier, List<FileTabState>>((ref) {
  return FileTabsNotifier(ref);
});

final loadingStateProvider = StateProvider<bool>((ref) => false);
final diagnosticsProvider = StateProvider<bool>((ref) => false);
final activeTabIndexProvider = StateProvider<int>((ref) => 0);
// Added: UI scroll request for navigation (index in visible list)
final scrollToIndexProvider = StateProvider<int?>((ref) => null);
final activeTabProvider = Provider<FileTabState?>((ref) {
  final tabs = ref.watch(fileTabsProvider);
  final activeTabIndex = ref.watch(activeTabIndexProvider);
  if (tabs.isEmpty || activeTabIndex >= tabs.length) return null;
  return tabs[activeTabIndex];
});

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
    state++;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class FileTabsNotifier extends StateNotifier<List<FileTabState>> {
  final Ref _ref;
  FileTabsNotifier(this._ref) : super([]);
  final ARXMLFileLoader _arxmlLoader = const ARXMLFileLoader();
  XsdParser? _currentXsdParser;
  String? _currentXsdPath;
  // Cache for detection per file content hash/path
  final Map<String, (String path, String source)> _detectionCache = {};

  @override
  set state(List<FileTabState> value) {
    // ignore: avoid_print
    print('[tabs] state set ${super.state.length} -> ${value.length}');
    super.state = value;
  }

  // Contract: parse header for schema hints
  // Returns: pairs, noNamespace href, version hint
  ({List<(String ns, String href)> pairs, String? noNsHref, String? version})
      _parseSchemaHeader(String content) {
    // Limit to header region for performance and robustness
    final header = content.split(RegExp(r'\r?\n')).take(120).join(' ');
    final pairs = <(String, String)>[];
    String? noNsHref;
    String? version;

    // xsi:schemaLocation may contain multiple namespace/URL pairs separated by spaces/newlines
    final schemaLocAttr =
        RegExp(r'xsi:schemaLocation\s*=\s*"([^"]+)"', caseSensitive: false)
            .firstMatch(header)
            ?.group(1);
    if (schemaLocAttr != null) {
      final tokens = schemaLocAttr
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      for (var i = 0; i + 1 < tokens.length; i += 2) {
        final ns = tokens[i];
        var href = tokens[i + 1];
        // Strip scheme, query, fragment for filesystem resolution
        final scheme = href.indexOf('://');
        if (scheme > 0) href = href.substring(scheme + 3);
        final hash = href.indexOf('#');
        if (hash >= 0) href = href.substring(0, hash);
        final q = href.indexOf('?');
        if (q >= 0) href = href.substring(0, q);
        pairs.add((ns, href));
      }
    }

    noNsHref = RegExp(r'noNamespaceSchemaLocation\s*=\s*"([^"]+)"',
            caseSensitive: false)
        .firstMatch(header)
        ?.group(1);

    version =
        RegExp(r'AUTOSAR[^>]*version\s*=\s*"([^"]+)"', caseSensitive: false)
            .firstMatch(header)
            ?.group(1)
            ?.trim();

    return (pairs: pairs, noNsHref: noNsHref, version: version);
  }

  Future<void> _loadXsdSchema() async {
    if (_currentXsdParser != null) return;
    try {
      final xsdFile = File('lib/res/xsd/AUTOSAR_00050.xsd');
      if (await xsdFile.exists()) {
        _currentXsdPath = xsdFile.path;
        final xsdContent = await xsdFile.readAsString();
        final verbose = _ref.read(diagnosticsProvider);
        _currentXsdParser = XsdParser(xsdContent, verbose: verbose);
      }
    } catch (_) {}
  }

  Future<void> toggleDiagnostics() async {
    final next = !_ref.read(diagnosticsProvider);
    _ref.read(diagnosticsProvider.notifier).state = next;
    await _rebuildParsersWithVerbose(next);
  }

  Future<void> _rebuildParsersWithVerbose(bool verbose) async {
    if (_currentXsdPath != null) {
      try {
        final content = await File(_currentXsdPath!).readAsString();
        _currentXsdParser = XsdParser(content, verbose: verbose);
      } catch (_) {}
    }
    final updated = <FileTabState>[];
    for (final tab in state) {
      XsdParser? parser = tab.xsdParser;
      if (tab.xsdPath != null) {
        try {
          final content = await File(tab.xsdPath!).readAsString();
          parser = XsdParser(content, verbose: verbose);
        } catch (_) {}
      } else {
        parser = _currentXsdParser;
      }
      updated.add(tab.copyWith(xsdParser: parser));
    }
    state = updated;
  }

  Future<String?> _detectSchemaPathFromArxml(String content) async {
    // Initialize catalog if not yet initialized (ensure bundled res is scanned)
    final catalogNotifier = _ref.read(xsdCatalogProvider.notifier);
    final catalog = _ref.read(xsdCatalogProvider);
    if (catalog.sources.isEmpty) {
      await catalogNotifier.initialize();
    }
    // Try cache (based on content hash)
    final key = content.hashCode.toString();
    final cached = _detectionCache[key];
    if (cached != null) return cached.$1;

    // Parse header hints
    final parsed = _parseSchemaHeader(content);
    final diag = _ref.read(diagnosticsProvider);
    if (diag) {
      log('[xsd-detect] header pairs=${parsed.pairs.length} noNs=${parsed.noNsHref ?? '-'} ver=${parsed.version ?? '-'}');
    }

    // Helper to try candidates with strict ordering
    Future<(String path, String source)?> _resolveOrdered(
        List<String> basenames) async {
      // 1) Catalog by basename
      final cat = _ref.read(xsdCatalogProvider.notifier).findAny(basenames);
      if (cat != null) {
        if (diag) log('[xsd-detect] match catalog by basename: $cat');
        return (cat, 'catalog:basename');
      }
      // 2) Direct file paths
      for (final c in basenames) {
        try {
          if (await File(c).exists()) {
            if (diag) log('[xsd-detect] match direct path: $c');
            return (c, 'direct');
          }
        } catch (_) {}
      }
      // 3) Bundled res by basename
      for (final c in basenames) {
        final base = c.split(RegExp(r'[\\\/]')).last;
        final bundled = 'lib/res/xsd/' + base;
        if (await File(bundled).exists()) {
          if (diag) log('[xsd-detect] match bundled: $bundled');
          return (bundled, 'bundled');
        }
      }
      // 4) Workspace search
      final wsRoot = _ref.read(workspaceIndexProvider).rootDir;
      if (wsRoot != null) {
        final hit = await _findInWorkspace(wsRoot, basenames);
        if (hit != null) {
          if (diag) log('[xsd-detect] match workspace: $hit');
          return (hit, 'workspace');
        }
      }
      return null;
    }

    // 1) schemaLocation namespace pairs
    if (parsed.pairs.isNotEmpty) {
      final urls = parsed.pairs.map((e) => e.$2).toList(growable: false);
      final resolved = await _resolveOrdered(urls);
      if (resolved != null) {
        _detectionCache[key] = resolved;
        if (diag)
          log('[xsd-detect] resolved from schemaLocation -> ${resolved.$2} :: ${resolved.$1}');
        return resolved.$1;
      }
    }
    // 2) noNamespaceSchemaLocation
    if (parsed.noNsHref != null) {
      final resolved = await _resolveOrdered([parsed.noNsHref!]);
      if (resolved != null) {
        _detectionCache[key] = resolved;
        if (diag)
          log('[xsd-detect] resolved from noNamespaceSchemaLocation -> ${resolved.$2} :: ${resolved.$1}');
        return resolved.$1;
      }
    }
    // 3) Version hint to catalog: exact or nearest
    if (parsed.version != null) {
      final verRaw = parsed.version!;
      final normalized = verRaw.replaceAll('-', '.');
      final exact = catalogNotifier.findByVersion(normalized);
      if (exact != null) {
        _detectionCache[key] = (exact, 'catalog:version');
        if (diag)
          log('[xsd-detect] resolved by exact version: $normalized -> $exact');
        return exact;
      }
      final nearest = catalogNotifier.findNearestVersion(normalized);
      if (nearest != null) {
        _detectionCache[key] = (nearest, 'catalog:nearest');
        if (diag)
          log('[xsd-detect] resolved by nearest version: $normalized -> $nearest');
        return nearest;
      }
      // If still not found, try common filename variants
      final variants = <String>[
        'AUTOSAR_$verRaw.xsd',
        'AUTOSAR_${normalized}.xsd',
        'AUTOSAR_${verRaw.replaceAll('.', '-')}.xsd',
      ];
      final viaNames = await _resolveOrdered(variants);
      if (viaNames != null) {
        _detectionCache[key] = viaNames;
        if (diag)
          log('[xsd-detect] resolved via filename variants -> ${viaNames.$2} :: ${viaNames.$1}');
        return viaNames.$1;
      }
    }
    // 4) Hard fallback
    final fallback = 'lib/res/xsd/AUTOSAR_00050.xsd';
    if (await File(fallback).exists()) {
      _detectionCache[key] = (fallback, 'fallback');
      if (diag) log('[xsd-detect] using fallback: $fallback');
      return fallback;
    }
    return null;
  }

  Future<String?> _findInWorkspace(
      String rootDir, List<String> basenames) async {
    try {
      final dir = Directory(rootDir);
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is File) {
          final name = ent.path.split(Platform.pathSeparator).last;
          if (basenames.contains(name)) return ent.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> pickXsdForActiveTab() async {
    final activeIndex = _ref.read(activeTabIndexProvider);
    if (state.isEmpty || activeIndex < 0 || activeIndex >= state.length) return;
    // Prefer choosing from discovered catalog entries
    final catalog = _ref.read(xsdCatalogProvider);
    String? filePath;
    if (catalog.byBasename.isNotEmpty) {
      // Pick the first entry for now; UI dialog selection can be added later.
      // Prefer normalized version match to active file if possible.
      final active = state[activeIndex];
      try {
        final content = await File(active.path).readAsString();
        final versionMatch =
            RegExp(r'AUTOSAR[^>]*version\s*=\s*"([^"]+)"').firstMatch(content);
        if (versionMatch != null) {
          final ver = versionMatch.group(1)!.replaceAll('-', '.');
          final byVersion =
              _ref.read(xsdCatalogProvider.notifier).findByVersion(ver);
          filePath = byVersion ?? catalog.byBasename.values.first;
        } else {
          filePath = catalog.byBasename.values.first;
        }
      } catch (_) {
        filePath = catalog.byBasename.values.first;
      }
    } else {
      // Fallback to manual file picker
      fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xsd'],
      );
      if (result != null && result.files.single.path != null) {
        filePath = result.files.single.path!;
      }
    }
    if (filePath != null) {
      await applyXsdToActiveTab(filePath);
    }
  }

  // Public helper for tests and UI: reuse detection logic
  Future<String?> detectSchemaForContent(String content) async =>
      _detectSchemaPathFromArxml(content);

  // Public method to set a specific XSD path as the active tab's schema
  Future<void> applyXsdToActiveTab(String filePath) async {
    final activeIndex = _ref.read(activeTabIndexProvider);
    if (state.isEmpty || activeIndex < 0 || activeIndex >= state.length) return;
    try {
      final content = await File(filePath).readAsString();
      final verbose = _ref.read(diagnosticsProvider);
      final parser = XsdParser(content, verbose: verbose);
      _currentXsdParser = parser;
      _currentXsdPath = filePath;
      final updated = [...state];
      final tab = updated[activeIndex];
      updated[activeIndex] = tab.copyWith(
        xsdParser: parser,
        xsdPath: filePath,
        xsdSource: 'manual',
      );
      state = updated;
    } catch (_) {}
  }

  Future<void> openNewFile() async {
    try {
      // ignore: avoid_print
      print('[tabs] openNewFile start');
      _ref.read(loadingStateProvider.notifier).state = true;
      await _loadXsdSchema();
      String? pickedPath;
      // Prefer a bundled sample file if available (useful in tests/CI)
      final samplePath = 'test/res/generic_ecu.arxml';
      if (await File(samplePath).exists()) {
        pickedPath = samplePath;
        // ignore: avoid_print
        print('[tabs] using sample file: ' + pickedPath);
      } else {
        fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
          type: fp.FileType.custom,
          allowedExtensions: ['arxml', 'xml'],
        );
        if (result != null && result.files.single.path != null) {
          pickedPath = result.files.single.path!;
          // ignore: avoid_print
          print('[tabs] picked file: ' + pickedPath);
        }
      }
      if (pickedPath != null) {
        final filePath = pickedPath;
        final cache = _ref.read(astCacheProvider);
        List<ElementNode>? nodes = cache.get(filePath);
        String fileContent;
        if (nodes == null) {
          fileContent = await File(filePath).readAsString();
          // ignore: avoid_print
          print('[tabs] read file content, length=' +
              fileContent.length.toString());
          final detectedSchema = await _detectSchemaPathFromArxml(fileContent);
          XsdParser? xsdForTab = _currentXsdParser;
          String? xsdPath = _currentXsdPath;
          if (detectedSchema != null) {
            try {
              final content = await File(detectedSchema).readAsString();
              xsdForTab =
                  XsdParser(content, verbose: _ref.read(diagnosticsProvider));
              xsdPath = detectedSchema;
            } catch (_) {}
          }
          nodes = _arxmlLoader.parseXmlContent(fileContent);
          // ignore: avoid_print
          print('[tabs] parsed nodes: ' + nodes.length.toString());
          cache.put(filePath, nodes);
          final newTab = FileTabState(
            path: filePath,
            treeStateProvider: arxmlTreeStateProvider(nodes),
            xsdParser: xsdForTab,
            xsdPath: xsdPath,
            xsdSource: xsdPath == null
                ? null
                : _detectionCache[fileContent.hashCode.toString()]?.$2,
          );
          state = [...state, newTab];
          _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
          // ignore: avoid_print
          print('[tabs] tab added, total tabs=' + state.length.toString());
        } else {
          final newTab = FileTabState(
            path: filePath,
            treeStateProvider: arxmlTreeStateProvider(nodes),
            xsdParser: _currentXsdParser,
            xsdPath: _currentXsdPath,
          );
          state = [...state, newTab];
          _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
          // ignore: avoid_print
          print('[tabs] tab added from cache, total tabs=' +
              state.length.toString());
        }
      }
    } catch (_) {
    } finally {
      _ref.read(loadingStateProvider.notifier).state = false;
      // ignore: avoid_print
      print('[tabs] openNewFile end');
    }
  }

  Future<void> createNewFile() async {
    await _loadXsdSchema();
    String? outputFile = await fp.FilePicker.platform.saveFile(
      dialogTitle: 'Please select where to save the new file:',
      fileName: 'new_file.arxml',
    );
    if (outputFile != null) {
      const String defaultContent =
          '''\n<?xml version="1.0" encoding="UTF-8"?>\n<AUTOSAR>\n</AUTOSAR>\n''';
      await File(outputFile).writeAsString(defaultContent);
      final fileContent = await File(outputFile).readAsString();
      final detectedSchema = await _detectSchemaPathFromArxml(fileContent);
      XsdParser? xsdForTab = _currentXsdParser;
      String? xsdPath = _currentXsdPath;
      if (detectedSchema != null) {
        try {
          final content = await File(detectedSchema).readAsString();
          xsdForTab =
              XsdParser(content, verbose: _ref.read(diagnosticsProvider));
          xsdPath = detectedSchema;
        } catch (_) {}
      }
      final nodes = _arxmlLoader.parseXmlContent(fileContent);
      final newTab = FileTabState(
        path: outputFile,
        treeStateProvider: arxmlTreeStateProvider(nodes),
        xsdParser: xsdForTab,
        xsdPath: xsdPath,
        xsdSource: xsdPath == null
            ? null
            : _detectionCache[fileContent.hashCode.toString()]?.$2,
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
    // Invalidate detection cache on save (content changed)
    _detectionCache.clear();
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
    // Invalidate detection cache on bulk save
    _detectionCache.clear();
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
    final existingIndex = state.indexWhere((t) => t.path == filePath);
    if (existingIndex != -1) {
      _ref.read(activeTabIndexProvider.notifier).state = existingIndex;
      _navigateToShortPath(state[existingIndex], shortNamePath);
      return;
    }
    try {
      _ref.read(loadingStateProvider.notifier).state = true;
      await _loadXsdSchema();
      final cache = _ref.read(astCacheProvider);
      List<ElementNode>? nodes = cache.get(filePath);
      String? content;
      if (nodes == null) {
        content = await File(filePath).readAsString();
        nodes = _arxmlLoader.parseXmlContent(content);
        cache.put(filePath, nodes);
      }
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
        xsdSource: xsdPath == null
            ? null
            : _detectionCache[(content ?? '').hashCode.toString()]?.$2,
      );
      state = [...state, tab];
      final idx = state.length - 1;
      _ref.read(activeTabIndexProvider.notifier).state = idx;
      await Future.delayed(const Duration(milliseconds: 50));
      _navigateToShortPath(tab, shortNamePath);
    } finally {
      _ref.read(loadingStateProvider.notifier).state = false;
    }
  }

  void _navigateToShortPath(FileTabState tab, List<String> shortNamePath) {
    final tree = _ref.read(tab.treeStateProvider);
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
        _ref.read(scrollToIndexProvider.notifier).state = index;
      }
    }
  }

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
    await _loadXsdSchema();
    final activeIndex = _ref.read(activeTabIndexProvider);
    if (state.isEmpty || activeIndex < 0 || activeIndex >= state.length) return;
    final updated = [...state];
    final tab = updated[activeIndex];
    updated[activeIndex] = tab.copyWith(
      xsdParser: _currentXsdParser,
      xsdPath: _currentXsdPath,
      xsdSource: _currentXsdPath == null ? null : 'session',
      isDirty: tab.isDirty,
    );
    state = updated;
  }
}
