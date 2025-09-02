import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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

  bool _isBundledPath(String path) {
    try {
      final norm = p.normalize(path).replaceAll('\\', '/');
      return norm.contains('/lib/res/xsd/');
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize({String bundledRes = 'lib/res/xsd'}) async {
    final resDir = p.normalize(bundledRes);
    // Load persisted sources (if any) in stable order, then ensure bundled res is appended last.
    final saved = await _loadSources();
    final sources = <String>[...saved];
    if (!sources.contains(resDir)) {
      sources.add(resDir);
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

  static String _normalizeVersionFromName(String name) {
    // Extract 1-2-3 or 1.2.3 and normalize to 1.2.3
    final m = RegExp(r'(\d+[.-]\d+[.-]\d+)').firstMatch(name);
    if (m == null) return '';
    return m.group(1)!.replaceAll('-', '.');
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
            final ver = _normalizeVersionFromName(base);
            if (ver.isNotEmpty) {
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

  String? findByBasename(String base) => state.byBasename[base];
  String? findByVersion(String version) => state.byVersion[version];

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
      final hit = state.byBasename[b];
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
