import '../models/element_node.dart';
import '../xsd/xsd_parser/parser.dart';

enum ValidationSeverity { error, warning, info }

class ValidationIssue {
  final String path;
  final String message;
  final List<String> suggestions;
  final int? nodeId;
  final ValidationSeverity severity;
  ValidationIssue({
    required this.path,
    required this.message,
    this.suggestions = const [],
    this.nodeId,
    this.severity = ValidationSeverity.error,
  });
}

class ValidationOptions {
  final bool ignoreAdminData;
  const ValidationOptions({this.ignoreAdminData = false});
}

class ArxmlValidator {
  const ArxmlValidator();

  List<ValidationIssue> validate(List<ElementNode> roots, XsdParser parser,
      {ValidationOptions options = const ValidationOptions()}) {
    final issues = <ValidationIssue>[];

    void assignParents(ElementNode node, ElementNode? parent) {
      node.parent = parent;
      for (final c in node.children) assignParents(c, node);
    }

    for (final r in roots) assignParents(r, null);

    String buildPath(ElementNode node) {
      final segs = <String>[];
      ElementNode? cur = node;
      while (cur != null) {
        segs.add(cur.elementText);
        cur = cur.parent;
      }
      return segs.reversed.join('/');
    }

    void traverse(ElementNode node) {
      if (options.ignoreAdminData && node.elementText == 'ADMIN-DATA') return;
      if (node.isValueNode) return;
      final isTextLeaf =
          node.children.length == 1 && node.children.first.isValueNode;
      if (!isTextLeaf && node.parent != null) {
        final parentTag = node.parent!.elementText;
        final allowed = parser.getValidChildElements(parentTag,
            contextElementName: parentTag);
        if (!allowed.contains(node.elementText)) {
          issues.add(ValidationIssue(
            path: buildPath(node),
            message:
                'Element "${node.elementText}" is not allowed under "$parentTag"',
            suggestions: allowed.take(5).toList(),
            nodeId: node.id,
          ));
        }
      }
      for (final c in node.children) traverse(c);
    }

    for (final r in roots) traverse(r);
    return issues;
  }
}
