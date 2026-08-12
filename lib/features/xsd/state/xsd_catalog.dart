import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arxml_explorer/core/resources/resource_locator.dart';

class XsdCatalogState {
  final List<String> sources; // directories to scan (absolute)
  final Map<String, String> byBasename; // basename -> full path
  final Map<String, String> byVersion; // normalized version -> full path
  final bool scanning;
  final int count;
  const XsdCatalogState({
    this.sources = const [],
    this.byBasename = const {},
    this.byVersion = const {},
    this.scanning = false,
    this.count = 0,
  });

  XsdCatalogState copyWith({
    List<String>? sources,
    Map<String, String>? byBasename,
    Map<String, String>? byVersion,
    bool? scanning,
    int? count,
  }) =>
      XsdCatalogState(
        sources: sources ?? this.sources,
        byBasename: byBasename ?? this.byBasename,
        byVersion: byVersion ?? this.byVersion,
        scanning: scanning ?? this.scanning,
        count: count ?? this.count,
      );
}

class XsdCatalogNotifier extends StateNotifier<XsdCatalogState> {
  XsdCatalogNotifier() : super(const XsdCatalogState());

  bool _isBundledPath(String path) => resourceLocator.isBundledPath(path);

  /// Load persisted sources, then append every bundled schema directory the
  /// [ResourceLocator] can find.
  ///
  /// [bundledRes] overrides discovery entirely (tests point it at a fixture
  /// directory); when omitted the locator decides, so the catalog populates
  /// from an installed build as well as a source checkout.
  Future<void> initialize({String? bundledRes}) async {
    final saved = await _loadSources();
    final sources = <String>[...saved];

    void addSourceIfMissing(String dir) {
      final norm = p.normalize(dir);
      if (!sources.contains(norm)) sources.add(norm);
    }

    if (bundledRes != null) {
      addSourceIfMissing(bundledRes);
    } else {
      for (final dir in resourceLocator.xsdSearchPaths()) {
        if (Directory(dir).existsSync()) addSourceIfMissing(dir);
      }
      // Nothing on disk yet: keep the checkout-relative path so a later rescan
      // picks schemas up once they are provisioned.
      if (sources.isEmpty) {
        addSourceIfMissing(ResourceLocator.bundledXsdRelative);
      }
    }

    state = state.copyWith(sources: sources);
    await rescan();
  }

  Future<void> addSource(String dir) async {
    final norm = p.normalize(dir);
    if (!Directory(norm).existsSync()) return;
    if (state.sources.contains(norm)) return;
    state = state.copyWith(sources: [...state.sources, norm]);
    await _saveSources(state.sources);
    await rescan();
  }

  Future<void> removeSource(String dir) async {
    final norm = p.normalize(dir);
    final nextSources = state.sources.where((s) => s != norm).toList();
    state = state.copyWith(sources: nextSources);
    await _saveSources(nextSources);
    await rescan();
  }

  /// Version keys a schema file should be indexed under.
  ///
  /// AUTOSAR ships two naming schemes and the old single-regex version only
  /// understood the first:
  ///   * dotted/dashed releases — `AUTOSAR_4-3-0.xsd` -> `4.3.0`
  ///   * numeric release ids    — `AUTOSAR_00050.xsd` -> `00050` and `50`
  ///
  /// Because `00050` has no separators it never matched `\d+[.-]\d+[.-]\d+`, so
  /// the nine newest bundled schemas — including the hard fallback — were absent
  /// from `byVersion` and `findByVersion`/`findNearestVersion` could never
  /// resolve them.
  static Set<String> _versionKeysFromName(String name) {
    final keys = <String>{};

    final dotted = RegExp(r'(\d+[.-]\d+[.-]\d+)').firstMatch(name);
    if (dotted != null) keys.add(dotted.group(1)!.replaceAll('-', '.'));

    final release = RegExp(r'_(\d{4,5})(?:\D|$)').firstMatch(name);
    if (release != null) {
      final raw = release.group(1)!;
      keys.add(raw);
      final trimmed = raw.replaceFirst(RegExp(r'^0+'), '');
      if (trimmed.isNotEmpty) keys.add(trimmed);
    }
    return keys;
  }

  /// Normalize a version as written in an ARXML header into a catalog key.
  static String normalizeVersionQuery(String version) {
    final v = version.trim().replaceAll('-', '.');
    // Numeric release ids may arrive zero-padded or not; index covers both.
    return v;
  }

  Future<void> rescan() async {
    state = state.copyWith(scanning: true);
    final byBase = <String, String>{};
    final byVer = <String, String>{};
    int cnt = 0;
    for (final dir in state.sources) {
      try {
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        await for (final ent in d.list(recursive: true, followLinks: false)) {
          if (ent is File && ent.path.toLowerCase().endsWith('.xsd')) {
            cnt++;
            final base = p.basename(ent.path);
            final existing = byBase[base];
            if (existing == null) {
              byBase[base] = ent.path;
            } else {
              final prevBundled = _isBundledPath(existing);
              final nextBundled = _isBundledPath(ent.path);
              // Prefer bundled path over non-bundled when duplicates
              if (nextBundled && !prevBundled) {
                byBase[base] = ent.path;
              } else if (!nextBundled && prevBundled) {
                // keep existing bundled
              } else {
                // Same category: last writer wins
                byBase[base] = ent.path;
              }
            }
            for (final ver in _versionKeysFromName(base)) {
              final existingVer = byVer[ver];
              if (existingVer == null) {
                byVer[ver] = ent.path;
              } else {
                final prevBundled = _isBundledPath(existingVer);
                final nextBundled = _isBundledPath(ent.path);
                if (nextBundled && !prevBundled) {
                  byVer[ver] = ent.path;
                } else if (!nextBundled && prevBundled) {
                  // keep existing bundled
                } else {
                  byVer[ver] = ent.path;
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    state = state.copyWith(
      scanning: false,
      byBasename: byBase,
      byVersion: byVer,
      count: cnt,
    );
  }

  String? findByBasename(String base) {
    final hit = state.byBasename[base];
    if (hit != null) return hit;
    // Linux filesystems are case-sensitive; ARXML headers are not consistent.
    final lower = base.toLowerCase();
    for (final entry in state.byBasename.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  String? findByVersion(String version) {
    final key = normalizeVersionQuery(version);
    final hit = state.byVersion[key];
    if (hit != null) return hit;
    // Numeric release ids: tolerate zero padding differences (50 <-> 00050).
    if (RegExp(r'^\d+$').hasMatch(key)) {
      final trimmed = key.replaceFirst(RegExp(r'^0+'), '');
      for (final entry in state.byVersion.entries) {
        if (entry.key.replaceFirst(RegExp(r'^0+'), '') == trimmed) {
          return entry.value;
        }
      }
    }
    return null;
  }

  /// Find the nearest version in the catalog, preferring same major.minor
  /// with the highest available patch. Returns null if no suitable version.
  String? findNearestVersion(String normalizedVersion) {
    try {
      List<int> _parts(String v) {
        final segs = v.split('.');
        final a = segs.isNotEmpty ? int.tryParse(segs[0]) ?? 0 : 0;
        final b = segs.length > 1 ? int.tryParse(segs[1]) ?? 0 : 0;
        final c = segs.length > 2 ? int.tryParse(segs[2]) ?? 0 : 0;
        return [a, b, c];
      }

      final target = _parts(normalizedVersion);
      String? bestPath;
      int bestPatch = -1;
      for (final entry in state.byVersion.entries) {
        final parts = _parts(entry.key);
        if (parts[0] == target[0] && parts[1] == target[1]) {
          if (parts[2] >= bestPatch) {
            bestPatch = parts[2];
            bestPath = entry.value;
          }
        }
      }
      return bestPath;
    } catch (_) {
      return null;
    }
  }

  String? findAny(List<String> basenames) {
    for (final b in basenames) {
      final hit = findByBasename(p.basename(b));
      if (hit != null) return hit;
    }
    return null;
  }

  // Persistence (stores sources between sessions)
  static const _prefsKey = 'xsdCatalog.sources.v1';
  Future<List<String>> _loadSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? const [];
      // Normalize to avoid duplicates across platforms
      return list.map((s) => p.normalize(s)).toSet().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveSources(List<String> sources) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Persist only unique normalized sources
      final uniq = sources.map((s) => p.normalize(s)).toSet().toList();
      await prefs.setStringList(_prefsKey, uniq);
    } catch (_) {
      // ignore persistence errors
    }
  }
}

final xsdCatalogProvider =
    StateNotifierProvider<XsdCatalogNotifier, XsdCatalogState>((ref) {
  final n = XsdCatalogNotifier();
  // Lazy initialize; callers can call initialize() explicitly from app start
  return n;
});
