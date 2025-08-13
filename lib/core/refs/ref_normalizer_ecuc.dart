import 'package:arxml_explorer/ref_normalizer.dart';

String normalizeEcucRef(String raw, {String? basePath}) =>
    RefNormalizer.normalizeEcuc(raw, basePath: basePath);
