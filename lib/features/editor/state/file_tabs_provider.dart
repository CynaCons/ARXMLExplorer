import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/arxml_tree_view_state.dart';
import 'package:arxml_explorer/xsd_parser.dart';
import 'package:arxml_explorer/arxml_validator.dart';
import 'package:arxml_explorer/app_providers.dart';
import 'package:arxml_explorer/workspace_indexer.dart';
import 'package:arxml_explorer/ast_cache.dart';
import 'package:arxml_explorer/arxmlloader.dart';
import 'package:arxml_explorer/elementnode.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;

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
    final header = content.split(RegExp(r'\r?\n')).take(100).join(' ');
    Future<String?> _resolveCandidates(List<String> candidates) async {
      for (final c in candidates) {
        try {
          if (await File(c).exists()) return c;
        } catch (_) {}
      }
      for (final c in candidates) {
        final base = c.split(RegExp(r'[\\\/]')).last;
        final bundled = 'lib/res/xsd/' + base;
        if (await File(bundled).exists()) return bundled;
      }
      final wsRoot = _ref.read(workspaceIndexProvider).rootDir;
      if (wsRoot != null) {
        final hit = await _findInWorkspace(wsRoot, candidates);
        if (hit != null) return hit;
      }
      return null;
    }

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
        if (i % 2 == 1) {
          var u = tokens[i];
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
    final noNsAttr = RegExp(r'noNamespaceSchemaLocation\s*=\s*"([^"]+)"')
        .firstMatch(header)
        ?.group(1);
    if (noNsAttr != null) {
      final resolved = await _resolveCandidates([noNsAttr]);
      if (resolved != null) return resolved;
    }
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
    final fallback = 'lib/res/xsd/AUTOSAR_00050.xsd';
    return await File(fallback).exists() ? fallback : null;
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
        _currentXsdParser = parser;
        _currentXsdPath = filePath;
        final updated = [...state];
        final tab = updated[activeIndex];
        updated[activeIndex] = tab.copyWith(
          xsdParser: parser,
          xsdPath: filePath,
        );
        state = updated;
      } catch (_) {}
    }
  }

  Future<void> openNewFile() async {
    try {
      _ref.read(loadingStateProvider.notifier).state = true;
      await _loadXsdSchema();
      fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['arxml', 'xml'],
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final cache = _ref.read(astCacheProvider);
        List<ElementNode>? nodes = cache.get(filePath);
        String fileContent;
        if (nodes == null) {
          fileContent = await File(filePath).readAsString();
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
          cache.put(filePath, nodes);
          final newTab = FileTabState(
            path: filePath,
            treeStateProvider: arxmlTreeStateProvider(nodes),
            xsdParser: xsdForTab,
            xsdPath: xsdPath,
          );
          state = [...state, newTab];
          _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          final newTab = FileTabState(
            path: filePath,
            treeStateProvider: arxmlTreeStateProvider(nodes),
            xsdParser: _currentXsdParser,
            xsdPath: _currentXsdPath,
          );
          state = [...state, newTab];
          _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
        }
      }
    } catch (_) {
    } finally {
      _ref.read(loadingStateProvider.notifier).state = false;
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
      isDirty: tab.isDirty,
    );
    state = updated;
  }
}
