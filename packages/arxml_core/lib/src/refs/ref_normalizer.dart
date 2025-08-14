class RefNormalizer {
  static String normalize(
    String raw, {
    String? basePath,
    bool stripNamespacePrefixes = true,
  }) {
    var s = raw.trim();
    if (s.isEmpty) return '/';
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1);
    }
    final schemeIdx = s.indexOf('://');
    if (schemeIdx > 0) {
      s = s.substring(schemeIdx + 3);
    }
    final hash = s.indexOf('#');
    if (hash >= 0) s = s.substring(0, hash);
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);
    s = s.replaceAll('::', '/').replaceAll('\\', '/');
    while (s.contains('//')) s = s.replaceAll('//', '/');
    final rawSegs = s.split('/').where((e) => e.isNotEmpty).toList();
    List<String> baseSegs = [];
    if (basePath != null && basePath.isNotEmpty) {
      var b = basePath.trim();
      b = b.replaceAll('::', '/').replaceAll('\\', '/');
      while (b.contains('//')) b = b.replaceAll('//', '/');
      baseSegs = b.split('/').where((e) => e.isNotEmpty).toList();
    }
    final out = <String>[];
    final isAbsolute = raw.startsWith('/') || (raw.startsWith('::'));
    if (!isAbsolute && baseSegs.isNotEmpty) {
      out.addAll(baseSegs);
    }
    for (var seg in rawSegs) {
      if (stripNamespacePrefixes) {
        final idx = seg.indexOf(':');
        if (idx > 0) seg = seg.substring(idx + 1);
      }
      if (seg == '.') continue;
      if (seg == '..') {
        if (out.isNotEmpty) out.removeLast();
        continue;
      }
      out.add(seg);
    }
    final joined = '/${out.join('/')}';
    return joined.isEmpty ? '/' : joined;
  }

  static String normalizeEcuc(String raw, {String? basePath}) {
    var n = normalize(raw, basePath: basePath);
    n = n.replaceAll('/ECUC-DEFINITION/', '/');
    n = n.replaceAll('/ECUC-MODULE-DEF/ECUC-MODULE-DEF/', '/ECUC-MODULE-DEF/');
    return n;
  }

  static String normalizePortRef(String raw, {String? basePath}) {
    var n = normalize(raw, basePath: basePath);
    n = n.replaceAll('/P-PORT-PROTOTYPE/', '/');
    n = n.replaceAll('/R-PORT-PROTOTYPE/', '/');
    n = n.replaceAll('/INTERFACE-REF/', '/');
    return n;
  }
}
