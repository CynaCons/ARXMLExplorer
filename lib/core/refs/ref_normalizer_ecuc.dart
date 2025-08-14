import 'package:arxml_explorer/core/refs/ref_normalizer.dart';

String normalizeEcucRef(String raw, {String? basePath}) =>
    RefNormalizer.normalizeEcuc(raw, basePath: basePath);
