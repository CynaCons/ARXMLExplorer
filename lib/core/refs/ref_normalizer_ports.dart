import 'package:arxml_explorer/core/refs/ref_normalizer.dart';

String normalizePortRef(String raw, {String? basePath}) =>
    RefNormalizer.normalizePortRef(raw, basePath: basePath);
