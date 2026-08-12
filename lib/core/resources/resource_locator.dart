import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves bundled resources (currently the AUTOSAR XSD directory) in a way
/// that works both from a source checkout and from an installed build.
///
/// The app used to read `lib/res/xsd/...` as a bare relative path, which only
/// resolves when the process working directory happens to be the repo root.
/// Anywhere else — a packaged desktop build, a test runner started from a
/// subdirectory, a shell launched from the user's home — schema discovery
/// silently found nothing.
///
/// Search order, first hit wins:
///   1. `ARXML_XSD_DIR` environment variable (explicit operator override)
///   2. `<cwd>/lib/res/xsd`            — source checkout / `flutter run`
///   3. `<executable dir>/data/flutter_assets/lib/res/xsd` — Flutter asset bundle
///   4. `<executable dir>/res/xsd`     — schemas shipped beside the binary
///   5. `<executable dir>/../res/xsd`  — Linux `bin/` + `share/` style layouts
///   6. Per-user data dir              — `%APPDATA%` / `$XDG_DATA_HOME` /
///                                       `~/.local/share` / `~/Library/Application Support`
class ResourceLocator {
  const ResourceLocator();

  /// Relative location of the schema directory inside a source checkout.
  static const String bundledXsdRelative = 'lib/res/xsd';

  /// Environment variable that overrides discovery entirely.
  static const String envOverride = 'ARXML_XSD_DIR';

  /// Cached result; discovery touches the filesystem so it is worth memoising.
  static String? _cachedXsdDir;

  /// Clears the memoised directory. Tests use this between cases.
  static void resetCache() => _cachedXsdDir = null;

  /// All candidate schema directories, in priority order.
  ///
  /// Exposed (rather than only [xsdDirectory]) so diagnostics can show the user
  /// exactly where the app looked when nothing was found.
  List<String> xsdSearchPaths() {
    final candidates = <String>[];

    void add(String? path) {
      if (path == null || path.isEmpty) return;
      final norm = p.normalize(path);
      if (!candidates.contains(norm)) candidates.add(norm);
    }

    add(_env(envOverride));
    add(p.join(Directory.current.path, bundledXsdRelative));

    final exeDir = _executableDir();
    if (exeDir != null) {
      add(p.join(exeDir, 'data', 'flutter_assets', 'lib', 'res', 'xsd'));
      add(p.join(exeDir, 'res', 'xsd'));
      add(p.join(p.dirname(exeDir), 'res', 'xsd'));
      add(p.join(p.dirname(exeDir), 'share', 'arxml_explorer', 'xsd'));
    }

    add(_userDataXsdDir());
    return candidates;
  }

  /// First existing schema directory, or `null` when none is present.
  String? xsdDirectory({bool useCache = true}) {
    if (useCache && _cachedXsdDir != null) return _cachedXsdDir;
    for (final candidate in xsdSearchPaths()) {
      try {
        if (Directory(candidate).existsSync()) {
          if (useCache) _cachedXsdDir = candidate;
          return candidate;
        }
      } on FileSystemException {
        // Unreadable candidate (permissions, dead symlink) — try the next one.
        continue;
      }
    }
    return null;
  }

  /// Resolve a schema by file name across the search paths.
  ///
  /// Falls back to a case-insensitive match because Linux filesystems are
  /// case-sensitive while the ARXML headers that name these files are not
  /// consistent about casing.
  String? resolveXsd(String basename) {
    if (basename.isEmpty) return null;
    final wanted = p.basename(basename);
    for (final dir in xsdSearchPaths()) {
      final direct = p.join(dir, wanted);
      try {
        if (File(direct).existsSync()) return direct;
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        final lower = wanted.toLowerCase();
        for (final entity in d.listSync(followLinks: false)) {
          if (entity is File &&
              p.basename(entity.path).toLowerCase() == lower) {
            return entity.path;
          }
        }
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  /// True when [path] sits under one of the bundled schema directories.
  ///
  /// Used to prefer bundled schemas over user-added copies when the catalog
  /// finds duplicates. Compares normalised paths rather than matching the
  /// literal substring `/lib/res/xsd/`, which broke on Windows separators.
  bool isBundledPath(String path) {
    final target = _canonical(path);
    for (final dir in xsdSearchPaths()) {
      final base = _canonical(dir);
      if (base.isNotEmpty && p.isWithin(base, target)) return true;
    }
    return false;
  }

  // ---- internals --------------------------------------------------------

  String _canonical(String path) {
    try {
      return p.normalize(p.absolute(path));
    } on Exception {
      return p.normalize(path);
    }
  }

  String? _env(String key) {
    try {
      final value = Platform.environment[key];
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    } on Exception {
      return null;
    }
  }

  String? _executableDir() {
    try {
      return p.dirname(Platform.resolvedExecutable);
    } on Exception {
      return null;
    }
  }

  /// Per-user location where operators can drop licensed AUTOSAR schemas.
  String? _userDataXsdDir() {
    try {
      if (Platform.isWindows) {
        final appData = _env('APPDATA');
        if (appData == null) return null;
        return p.join(appData, 'ARXMLExplorer', 'xsd');
      }
      final home = _env('HOME');
      if (Platform.isMacOS && home != null) {
        return p.join(
            home, 'Library', 'Application Support', 'ARXMLExplorer', 'xsd');
      }
      // Linux and other POSIX platforms: follow the XDG base directory spec.
      final xdg = _env('XDG_DATA_HOME');
      if (xdg != null) return p.join(xdg, 'arxml_explorer', 'xsd');
      if (home != null) {
        return p.join(home, '.local', 'share', 'arxml_explorer', 'xsd');
      }
      return null;
    } on Exception {
      return null;
    }
  }
}

/// Shared instance. Stateless apart from the memoised directory.
const ResourceLocator resourceLocator = ResourceLocator();
