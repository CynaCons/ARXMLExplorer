import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/xsd_parser.dart';

enum ValidationSeverity { error, warning, info }

class ValidationIssue {
  final String path;
  final String message;
  final List<String> suggestions;
  final int? nodeId; // precise node mapping when available
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

  List<ValidationIssue> validate(
    List<ElementNode> roots,
    XsdParser parser, {
    ValidationOptions options = const ValidationOptions(),
  }) {
    final issues = <ValidationIssue>[];

    // Build parent pointers locally (ElementNode.parent is set by state normally)
    void assignParents(ElementNode node, ElementNode? parent) {
      node.parent = parent;
      for (final c in node.children) {
        assignParents(c, node);
      }
    }

    for (final r in roots) {
      assignParents(r, null);
    }

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
      // Optionally skip ADMIN-DATA subtree entirely
      if (options.ignoreAdminData && node.elementText == 'ADMIN-DATA') {
        return;
      }

      // Skip pure text leaf nodes
      final isTextLeaf = node.children.isEmpty &&
          node.elementText.trim().isNotEmpty &&
          !node.elementText.contains('<') &&
          !node.elementText.contains('>');
      if (!isTextLeaf && node.parent != null) {
        final parentTag = node.parent!.elementText;
        final allowed = parser.getValidChildElements(parentTag);
        if (!allowed.contains(node.elementText)) {
          final suggestions = allowed.take(5).toList();
          issues.add(ValidationIssue(
            path: buildPath(node),
            message:
                'Element "${node.elementText}" is not allowed under "$parentTag"',
            suggestions: suggestions,
            nodeId: node.id,
            severity: ValidationSeverity.error,
          ));
        }
      }
      for (final c in node.children) {
        traverse(c);
      }
    }

    for (final r in roots) {
      traverse(r);
    }

    return issues;
  }
}
