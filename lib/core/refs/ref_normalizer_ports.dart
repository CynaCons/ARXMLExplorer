import 'package:arxml_explorer/ref_normalizer.dart';

String normalizePortRef(String raw, {String? basePath}) =>
    RefNormalizer.normalizePortRef(raw, basePath: basePath);
