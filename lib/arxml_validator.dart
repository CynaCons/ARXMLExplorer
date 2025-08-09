import 'package:arxml_explorer/elementnode.dart';
import 'package:arxml_explorer/xsd_parser.dart';

class ValidationIssue {
  final String path;
  final String message;
  final List<String> suggestions;
  ValidationIssue(
      {required this.path, required this.message, this.suggestions = const []});
}

class ArxmlValidator {
  const ArxmlValidator();

  List<ValidationIssue> validate(List<ElementNode> roots, XsdParser parser) {
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
