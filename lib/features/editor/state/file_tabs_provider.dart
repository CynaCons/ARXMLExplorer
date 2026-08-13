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
import 'package:file_picker/file_picker.dart' as fp;
import 'package:path/path.dart' as p;
import 'package:arxml_explorer/core/diagnostics/log.dart';
import 'package:arxml_explorer/core/resources/resource_locator.dart';
import 'package:arxml_explorer/features/xsd/state/xsd_catalog.dart';

// Removed obsolete placeholder comment after migration.

final fileTabsProvider =
    StateNotifierProvider<FileTabsNotifier, List<FileTabState>>((ref) {
  return FileTabsNotifier(ref);
});

final loadingStateProvider = StateProvider<bool>((ref) => false);

/// Whether opening a file should detect and parse its XSD automatically.
///
/// On by default. An AUTOSAR schema is ~9 MB and parsing it costs seconds on
/// the main isolate, so tests that only exercise tree/editing behaviour turn
/// this off rather than paying for it on every fixture open.
final autoAttachSchemaProvider = StateProvider<bool>((ref) => true);
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

  void _switchToEditorView() {
    _ref.read(navRailIndexProvider.notifier).state = 0;
  }

  final ARXMLFileLoader _arxmlLoader = const ARXMLFileLoader();
  XsdParser? _currentXsdParser;
  String? _currentXsdPath;
  // Cache for detection per file content hash/path
  final Map<String, (String path, String source)> _detectionCache = {};

  /// Last user-facing failure, surfaced by the shell instead of being swallowed.
  String? lastError;

  /// Completes when the schema for the most recently opened tab has been
  /// detected and parsed. Tests await this when they need validation ready;
  /// the UI does not, so a tab opens without waiting on a 9 MB XSD parse.
  Future<void>? schemaWarmup;

  /// Detects, loads and attaches the schema for an already-open tab.
  Future<void> _attachSchemaForTab(String filePath, String fileContent) async {
    if (!_ref.read(autoAttachSchemaProvider)) {
      Log.debug('xsd', 'auto-attach disabled; skipping schema for $filePath');
      return;
    }
    try {
      await _loadXsdSchema();
      final detected = await _detectSchemaPathFromArxml(fileContent);
      XsdParser? parser = _currentXsdParser;
      String? xsdPath = _currentXsdPath;
      if (detected != null) {
        try {
          final content = await File(detected).readAsString();
          parser = XsdParser(content, verbose: _ref.read(diagnosticsProvider));
          xsdPath = detected;
        } catch (e, st) {
          Log.warn('xsd', 'Failed to read detected schema $detected', e, st);
        }
      }
      if (!mounted) return; // notifier disposed while we were parsing
      final index = state.indexWhere((t) => t.path == filePath);
      if (index == -1) return; // tab closed while we were parsing
      final updated = [...state];
      updated[index] = updated[index].copyWith(
        xsdParser: parser,
        xsdPath: xsdPath,
        xsdSource: xsdPath == null
            ? null
            : _detectionCache[fileContent.hashCode.toString()]?.$2,
      );
      state = updated;
      Log.debug('xsd', 'schema attached to $filePath: ${xsdPath ?? "none"}');
    } catch (e, st) {
      Log.warn('xsd', 'schema attach failed for $filePath', e, st);
    }
  }

  @override
  set state(List<FileTabState> value) {
    Log.debug('tabs', 'state ${super.state.length} -> ${value.length}');
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

  /// Default schema name used when an ARXML gives no usable hint.
  static const String _defaultSchemaName = 'AUTOSAR_00050.xsd';

  Future<void> _loadXsdSchema() async {
    if (_currentXsdParser != null) return;
    final resolved = resourceLocator.resolveXsd(_defaultSchemaName);
    if (resolved == null) {
      Log.warn(
        'xsd',
        'Default schema $_defaultSchemaName not found. Searched: '
            '${resourceLocator.xsdSearchPaths().join(", ")}',
      );
      return;
    }
    try {
      _currentXsdPath = resolved;
      final xsdContent = await File(resolved).readAsString();
      final verbose = _ref.read(diagnosticsProvider);
      _currentXsdParser = XsdParser(xsdContent, verbose: verbose);
    } catch (e, st) {
      Log.warn('xsd', 'Failed to load default schema $resolved', e, st);
    }
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
      } catch (e, st) {
        Log.warn(
            'xsd', 'Failed to reload session schema $_currentXsdPath', e, st);
      }
    }
    final updated = <FileTabState>[];
    for (final tab in state) {
      XsdParser? parser = tab.xsdParser;
      if (tab.xsdPath != null) {
        try {
          final content = await File(tab.xsdPath!).readAsString();
          parser = XsdParser(content, verbose: verbose);
        } catch (e, st) {
          Log.warn('xsd', 'Failed to reload tab schema ${tab.xsdPath}', e, st);
        }
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
    Log.verbose(
        diag,
        'xsd-detect',
        'header pairs=${parsed.pairs.length} '
            'noNs=${parsed.noNsHref ?? '-'} ver=${parsed.version ?? '-'}');

    // Strict fallback ordering, documented in PLAN v0.2.7:
    //   catalog basename -> direct path -> bundled -> workspace -> default.
    Future<(String path, String source)?> resolveOrdered(
        List<String> basenames) async {
      // 1) Catalog by basename
      final cat = _ref.read(xsdCatalogProvider.notifier).findAny(basenames);
      if (cat != null) {
        Log.verbose(diag, 'xsd-detect', 'match catalog by basename: $cat');
        return (cat, 'catalog:basename');
      }
      // 2) Direct file paths as written in the header
      for (final c in basenames) {
        try {
          if (await File(c).exists()) {
            Log.verbose(diag, 'xsd-detect', 'match direct path: $c');
            return (c, 'direct');
          }
        } catch (e) {
          Log.verbose(
              diag, 'xsd-detect', 'direct path check failed for $c: $e');
        }
      }
      // 3) Bundled schema directories (locator-resolved, not cwd-relative)
      for (final c in basenames) {
        final bundled = resourceLocator.resolveXsd(p.basename(c));
        if (bundled != null) {
          Log.verbose(diag, 'xsd-detect', 'match bundled: $bundled');
          return (bundled, 'bundled');
        }
      }
      // 4) Workspace search
      final wsRoot = _ref.read(workspaceIndexProvider).rootDir;
      if (wsRoot != null) {
        final hit = await _findInWorkspace(wsRoot, basenames);
        if (hit != null) {
          Log.verbose(diag, 'xsd-detect', 'match workspace: $hit');
          return (hit, 'workspace');
        }
      }
      return null;
    }

    // 1) schemaLocation namespace pairs
    if (parsed.pairs.isNotEmpty) {
      final urls = parsed.pairs.map((e) => e.$2).toList(growable: false);
      final resolved = await resolveOrdered(urls);
      if (resolved != null) {
        _detectionCache[key] = resolved;
        Log.verbose(diag, 'xsd-detect',
            'resolved from schemaLocation -> ${resolved.$2} :: ${resolved.$1}');
        return resolved.$1;
      }
    }
    // 2) noNamespaceSchemaLocation
    if (parsed.noNsHref != null) {
      final resolved = await resolveOrdered([parsed.noNsHref!]);
      if (resolved != null) {
        _detectionCache[key] = resolved;
        Log.verbose(
            diag,
            'xsd-detect',
            'resolved from noNamespaceSchemaLocation -> '
                '${resolved.$2} :: ${resolved.$1}');
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
        Log.verbose(diag, 'xsd-detect',
            'resolved by exact version: $normalized -> $exact');
        return exact;
      }
      final nearest = catalogNotifier.findNearestVersion(normalized);
      if (nearest != null) {
        _detectionCache[key] = (nearest, 'catalog:nearest');
        Log.verbose(diag, 'xsd-detect',
            'resolved by nearest version: $normalized -> $nearest');
        return nearest;
      }
      // If still not found, try common filename variants
      final variants = <String>[
        'AUTOSAR_$verRaw.xsd',
        'AUTOSAR_$normalized.xsd',
        'AUTOSAR_${verRaw.replaceAll('.', '-')}.xsd',
      ];
      final viaNames = await resolveOrdered(variants);
      if (viaNames != null) {
        _detectionCache[key] = viaNames;
        Log.verbose(
            diag,
            'xsd-detect',
            'resolved via filename variants -> '
                '${viaNames.$2} :: ${viaNames.$1}');
        return viaNames.$1;
      }
    }
    // 5) Hard fallback: the newest bundled schema, wherever it lives.
    final fallback = resourceLocator.resolveXsd(_defaultSchemaName);
    if (fallback != null) {
      _detectionCache[key] = (fallback, 'fallback');
      Log.verbose(diag, 'xsd-detect', 'using fallback: $fallback');
      return fallback;
    }
    Log.warn(
      'xsd-detect',
      'No schema resolved and no bundled fallback found. Searched: '
          '${resourceLocator.xsdSearchPaths().join(", ")}',
    );
    return null;
  }

  Future<String?> _findInWorkspace(
      String rootDir, List<String> basenames) async {
    // Compare on basename so a header naming `schema/AUTOSAR_00050.xsd` still
    // matches, and so the split works on either path separator.
    final wanted = basenames.map(p.basename).toSet();
    try {
      final dir = Directory(rootDir);
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is File && wanted.contains(p.basename(ent.path))) {
          return ent.path;
        }
      }
    } on FileSystemException catch (e) {
      Log.warn('xsd-detect', 'workspace scan of $rootDir failed: $e');
    }
    return null;
  }

  /// Schemas offered to the user for the active tab, best match first.
  ///
  /// Exposed so the UI can present a real chooser; `pickXsdForActiveTab`
  /// previously just took `catalog.byBasename.values.first`.
  Future<List<String>> schemaChoicesForActiveTab() async {
    final catalog = _ref.read(xsdCatalogProvider);
    final choices = catalog.byBasename.values.toSet().toList()..sort();
    final suggested = await suggestedSchemaForActiveTab();
    if (suggested != null) {
      choices
        ..remove(suggested)
        ..insert(0, suggested);
    }
    return choices;
  }

  /// Best-guess schema for the active tab, from its own header.
  Future<String?> suggestedSchemaForActiveTab() async {
    final activeIndex = _ref.read(activeTabIndexProvider);
    if (state.isEmpty || activeIndex < 0 || activeIndex >= state.length) {
      return null;
    }
    try {
      final content = await File(state[activeIndex].path).readAsString();
      return await _detectSchemaPathFromArxml(content);
    } catch (e) {
      Log.warn('xsd', 'Could not read active file for schema suggestion: $e');
      return null;
    }
  }

  /// Applies a schema to the active tab.
  ///
  /// [chooser] lets the UI present the catalog; when omitted (or when it
  /// returns null) this falls back to the platform file picker.
  Future<void> pickXsdForActiveTab({
    Future<String?> Function(List<String> choices)? chooser,
  }) async {
    final activeIndex = _ref.read(activeTabIndexProvider);
    if (state.isEmpty || activeIndex < 0 || activeIndex >= state.length) return;
    final catalog = _ref.read(xsdCatalogProvider);
    String? filePath;
    if (catalog.byBasename.isNotEmpty && chooser != null) {
      filePath = await chooser(await schemaChoicesForActiveTab());
      if (filePath == null) return; // user dismissed the chooser
    } else if (catalog.byBasename.isNotEmpty) {
      // No chooser supplied (tests, headless): use the best automatic match.
      final choices = await schemaChoicesForActiveTab();
      filePath = await suggestedSchemaForActiveTab() ??
          (choices.isEmpty ? null : choices.first);
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
      lastError = null;
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
    } catch (e, st) {
      lastError = 'Could not load schema $filePath: $e';
      Log.error('xsd', 'applyXsdToActiveTab failed for $filePath', e, st);
    }
  }

  /// Opens a file.
  ///
  /// [path] bypasses the picker; tests pass a fixture here. Production callers
  /// omit it and always get the platform file dialog. (This used to silently
  /// prefer `test/res/generic_ecu.arxml` whenever that path existed, which meant
  /// Open File never prompted when the app ran from the repo root.)
  Future<void> openNewFile({String? path}) async {
    lastError = null;
    try {
      Log.debug('tabs', 'openNewFile start');
      _ref.read(loadingStateProvider.notifier).state = true;
      String? pickedPath = path;
      if (pickedPath == null) {
        fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
          type: fp.FileType.custom,
          allowedExtensions: ['arxml', 'xml'],
        );
        if (result != null && result.files.single.path != null) {
          pickedPath = result.files.single.path!;
        }
      }
      if (pickedPath == null) {
        Log.debug('tabs', 'openNewFile cancelled');
      } else {
        final filePath = pickedPath;
        final cache = _ref.read(astCacheProvider);
        List<ElementNode>? nodes = cache.get(filePath);
        String fileContent;
        if (nodes == null) {
          fileContent = await File(filePath).readAsString();
          Log.debug('tabs', 'read $filePath (${fileContent.length} chars)');
          nodes = _arxmlLoader.parseXmlContent(fileContent);
          Log.debug('tabs', 'parsed ${nodes.length} root nodes');
          cache.put(filePath, nodes);
          final newTab = FileTabState(
            path: filePath,
            treeStateProvider: arxmlTreeStateProvider(nodes),
            xsdParser: _currentXsdParser,
            xsdPath: _currentXsdPath,
          );
          state = [...state, newTab];
          _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
          _switchToEditorView();
          Log.debug('tabs', 'tab added, total=${state.length}');
          // Schema attachment is deferred: an AUTOSAR XSD is ~9 MB and parsing
          // it took multiple seconds *before* the tab appeared, so Open File
          // froze the UI. The tree is usable immediately; validation lights up
          // when the schema lands. Await `schemaWarmup` for determinism.
          schemaWarmup = _attachSchemaForTab(filePath, fileContent);
        } else {
          final newTab = FileTabState(
            path: filePath,
            treeStateProvider: arxmlTreeStateProvider(nodes),
            xsdParser: _currentXsdParser,
            xsdPath: _currentXsdPath,
          );
          state = [...state, newTab];
          _ref.read(activeTabIndexProvider.notifier).state = state.length - 1;
          _switchToEditorView();
          Log.debug('tabs', 'tab added from cache, total=${state.length}');
        }
      }
    } catch (e, st) {
      // Previously swallowed: a failed read or parse produced no tab and no
      // message, which read to the user as "Open File does nothing".
      lastError = 'Could not open file: $e';
      Log.error('tabs', 'openNewFile failed', e, st);
    } finally {
      _ref.read(loadingStateProvider.notifier).state = false;
      Log.debug('tabs', 'openNewFile end');
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
      _switchToEditorView();
    }
  }

  /// The active tab, resolved without going through [activeTabProvider].
  ///
  /// `activeTabProvider` watches `fileTabsProvider`, so reading it from inside
  /// this notifier is a cycle and Riverpod throws `CircularDependencyError`.
  /// That went unnoticed while Save had no UI to invoke it.
  FileTabState? get _activeTab {
    final index = _ref.read(activeTabIndexProvider);
    if (index < 0 || index >= state.length) return null;
    return state[index];
  }

  Future<void> saveActiveFile() async {
    final activeTab = _activeTab;
    if (activeTab == null) return;
    try {
      lastError = null;
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
      Log.debug('tabs', 'saved ${activeTab.path}');
    } catch (e, st) {
      lastError = 'Could not save ${activeTab.path}: $e';
      Log.error('tabs', 'saveActiveFile failed', e, st);
    }
  }

  Future<void> saveAllFiles() async {
    lastError = null;
    final failures = <String>[];
    for (var i = 0; i < state.length; i++) {
      final tab = state[i];
      try {
        final treeState = _ref.read(tab.treeStateProvider);
        final xmlString = _arxmlLoader.toXmlString(treeState.rootNodes);
        await File(tab.path).writeAsString(xmlString);
      } catch (e, st) {
        failures.add(p.basename(tab.path));
        Log.error('tabs', 'saveAllFiles failed for ${tab.path}', e, st);
      }
    }
    // Invalidate detection cache on bulk save
    _detectionCache.clear();
    // Only clear the dirty flag on files that actually made it to disk.
    state = [
      for (final t in state)
        failures.contains(p.basename(t.path)) ? t : t.copyWith(isDirty: false)
    ];
    if (failures.isNotEmpty) {
      lastError = 'Could not save: ${failures.join(", ")}';
    }
  }

  void closeFile(int index) {
    if (index < 0 || index >= state.length) return;
    // Release the tab's tree state. arxmlTreeStateProvider is an autoDispose
    // family that calls ref.keepAlive(), so without this the parsed AST — which
    // is also the family key — is retained for the life of the process.
    _ref.invalidate(state[index].treeStateProvider);
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
      _switchToEditorView();
      return;
    }
    try {
      _ref.read(loadingStateProvider.notifier).state = true;
      final cache = _ref.read(astCacheProvider);
      List<ElementNode>? nodes = cache.get(filePath);
      String? content;
      if (nodes == null) {
        content = await File(filePath).readAsString();
        nodes = _arxmlLoader.parseXmlContent(content);
        cache.put(filePath, nodes);
      }
      final tab = FileTabState(
        path: filePath,
        treeStateProvider: arxmlTreeStateProvider(nodes),
        xsdParser: _currentXsdParser,
        xsdPath: _currentXsdPath,
      );
      state = [...state, tab];
      final idx = state.length - 1;
      _ref.read(activeTabIndexProvider.notifier).state = idx;
      _switchToEditorView();
      _navigateToShortPath(tab, shortNamePath);
      // Same deferral as openNewFile: navigation must not wait on a 9 MB parse.
      if (content != null) {
        schemaWarmup = _attachSchemaForTab(filePath, content);
      }
    } catch (e, st) {
      lastError = 'Could not open $filePath: $e';
      Log.error('tabs', 'openFileAndNavigate failed', e, st);
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
      final index = updated.indexOfVisible(targetId) ?? -1;
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
