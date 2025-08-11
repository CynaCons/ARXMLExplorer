class RefNormalizer {
  /// Normalize a raw reference string to a canonical absolute form.
  /// - Strips URI schemes (e.g., file://, package://)
  /// - Removes URL fragments (#...) and queries (?...)
  /// - Converts backslashes and vendor separators (::) to '/'
  /// - Collapses multiple slashes
  /// - Trims quotes and whitespace
  /// - Resolves '.' and '..' segments against [basePath] when provided
  /// - Ensures a leading '/'
  /// - If [stripNamespacePrefixes] is true, strips 'ns:' style prefixes per segment
  static String normalize(
    String raw, {
    String? basePath,
    bool stripNamespacePrefixes = true,
  }) {
    var s = raw.trim();
    if (s.isEmpty) return '/';

    // Trim matching quotes
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1);
    }

    // Strip URI scheme if present (e.g., file:///path)
    final schemeIdx = s.indexOf('://');
    if (schemeIdx > 0) {
      s = s.substring(schemeIdx + 3);
      // If Windows drive like C:/ remains, keep as-is; will be treated as absolute
    }

    // Remove fragment and query
    final hash = s.indexOf('#');
    if (hash >= 0) s = s.substring(0, hash);
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);

    // Replace vendor separators and backslashes with '/'
    s = s.replaceAll('::', '/').replaceAll('\\', '/');

    // Collapse multiple slashes
    while (s.contains('//')) {
      s = s.replaceAll('//', '/');
    }

    // Split into segments and filter empties
    final rawSegs = s.split('/').where((e) => e.isNotEmpty).toList();

    List<String> baseSegs = [];
    if (basePath != null && basePath.isNotEmpty) {
      var b = basePath.trim();
      b = b.replaceAll('::', '/').replaceAll('\\', '/');
      while (b.contains('//')) {
        b = b.replaceAll('//', '/');
      }
      baseSegs = b.split('/').where((e) => e.isNotEmpty).toList();
    }

    final out = <String>[];

    // If path is absolute (leading '/') keep absolute context; otherwise start from base if given
    final isAbsolute = raw.startsWith('/') || (raw.startsWith('::'));
    if (!isAbsolute && baseSegs.isNotEmpty) {
      out.addAll(baseSegs);
    } else if (isAbsolute) {
      // absolute resets to root
    }

    for (var seg in rawSegs) {
      if (stripNamespacePrefixes) {
        final idx = seg.indexOf(':');
        if (idx > 0) seg = seg.substring(idx + 1);
      }
      if (seg == '.') {
        continue;
      }
      if (seg == '..') {
        if (out.isNotEmpty) out.removeLast();
        continue;
      }
      out.add(seg);
    }

    final joined = '/${out.join('/')}';
    return joined.isEmpty ? '/' : joined;
  }

  /// Normalize ECUC-style references which may point into ECUC-MODULE-DEF trees
  /// and PARAM-REF/REFERENCE-VALUES. Applies generic normalize first, then
  /// applies small fixups for common vendor/idiosyncratic segments.
  static String normalizeEcuc(String raw, {String? basePath}) {
    var n = normalize(raw, basePath: basePath);
    // Example fixups (can be extended as needed):
    // - Strip typical suffixes like 'ECUC-DEFINITION' segment aliases
    n = n.replaceAll('/ECUC-DEFINITION/', '/');
    // - Collapse duplicated ECUC-MODULE-DEF
    n = n.replaceAll('/ECUC-MODULE-DEF/ECUC-MODULE-DEF/', '/ECUC-MODULE-DEF/');
    return n;
  }

  /// Normalize ports/interfaces references (e.g., P-PORT-PROTOTYPE/R-PORT-PROTOTYPE
  /// to interface short-name path). This primarily relies on generic normalize
  /// and optional basePath, but provides a hook for port-specific rewrites.
  static String normalizePortRef(String raw, {String? basePath}) {
    var n = normalize(raw, basePath: basePath);
    // Example: Some refs may include 'PORT-PROTOTYPE' intermediate tokens
    n = n.replaceAll('/P-PORT-PROTOTYPE/', '/');
    n = n.replaceAll('/R-PORT-PROTOTYPE/', '/');
    // Some vendor formats embed INTERFACE-REF-like nodes
    n = n.replaceAll('/INTERFACE-REF/', '/');
    return n;
  }
}
