import 'package:xml/xml.dart';

class XsdParser {
  final XmlDocument document;
  final bool verbose;

  // Cache to avoid repeated expensive lookups
  final Map<String, List<String>> _childElementsCache = {};
  final Map<String, XmlElement> _elementDefsCache = {};
  final Map<String, XmlElement> _groupDefsCache = {};
  final Map<String, XmlElement> _typeDefsCache = {};

  // Indexes for fast lookup by @name (namespace-agnostic)
  Map<String, XmlElement>? _elementsByName;
  Map<String, XmlElement>? _groupsByName;
  Map<String, XmlElement>? _typesByName;

  // Lazy-loaded collections
  List<XmlElement>? _elementDefinitions;
  List<XmlElement>? _groupDefinitions;
  List<XmlElement>? _complexTypeDefinitions;

  XsdParser(String xsdContent, {this.verbose = false})
      : document = XmlDocument.parse(xsdContent);

  List<String> getValidChildElements(String parentElementName) {
    // Check cache first
    if (_childElementsCache.containsKey(parentElementName)) {
      return _childElementsCache[parentElementName]!;
    }

    final List<String> validChildElements = [];

    // Initialize lazy collections only when needed
    _elementDefinitions ??= [
      ...document.findAllElements('xs:element'),
      ...document.findAllElements('xsd:element')
    ];

    _groupDefinitions ??= [
      ...document.findAllElements('xs:group'),
      ...document.findAllElements('xsd:group')
    ];

    // Build indexes for fast lookup
    _ensureIndexes();

    // Find element or group with timeout protection
    var parentElementDef = _findElementDef(parentElementName);

    if (parentElementDef == null) {
      parentElementDef = _findGroupDef(parentElementName);
    }

    if (parentElementDef != null) {
      try {
        // Use a visited set to prevent infinite recursion
        final visited = <String>{};
        _extractChildElementsWithTimeoutAndVisited(
            parentElementDef, validChildElements, visited);
      } catch (e) {
        // If extraction takes too long or fails, return empty list
        if (verbose) {
          print('XSD: Could not extract children for $parentElementName: $e');
        }
      }
    }

    // Cache the result
    final result = validChildElements.toSet().toList();
    _childElementsCache[parentElementName] = result;
    return result;
  }

  void _ensureIndexes() {
    if (_elementsByName == null) {
      _elementsByName = {};
      for (final el in [
        ...document.findAllElements('xs:element'),
        ...document.findAllElements('xsd:element')
      ]) {
        final name = el.getAttribute('name');
        if (name != null && name.isNotEmpty) {
          _elementsByName![name] = el;
        }
      }
    }
    if (_groupsByName == null) {
      _groupsByName = {};
      for (final el in [
        ...document.findAllElements('xs:group'),
        ...document.findAllElements('xsd:group')
      ]) {
        final name = el.getAttribute('name');
        if (name != null && name.isNotEmpty) {
          _groupsByName![name] = el;
        }
      }
    }
    if (_typesByName == null) {
      _typesByName = {};
      _complexTypeDefinitions ??= [
        ...document.findAllElements('xs:complexType'),
        ...document.findAllElements('xsd:complexType')
      ];
      for (final el in _complexTypeDefinitions!) {
        final name = el.getAttribute('name');
        if (name != null && name.isNotEmpty) {
          _typesByName![name] = el;
        }
      }
    }
  }

  String _stripPrefix(String name) =>
      name.contains(':') ? name.split(':').last : name;

  XmlElement? _findElementDef(String name) {
    if (_elementDefsCache.containsKey(name)) {
      final cached = _elementDefsCache[name];
      return cached!.name.local == 'dummy' ? null : cached;
    }

    _ensureIndexes();
    final key = _stripPrefix(name);
    final found = _elementsByName![key];
    if (found != null) {
      _elementDefsCache[name] = found;
      return found;
    }

    // Fallback linear search with a reasonable limit to avoid infinite loops
    int searchCount = 0;
    const maxSearches = 1000;

    for (var element in _elementDefinitions!) {
      if (++searchCount > maxSearches) break;
      if (element.getAttribute('name') == key) {
        _elementDefsCache[name] = element;
        return element;
      }
    }

    _elementDefsCache[name] = XmlElement(XmlName('dummy'));
    return null;
  }

  XmlElement? _findGroupDef(String name) {
    if (_groupDefsCache.containsKey(name)) {
      final cached = _groupDefsCache[name];
      return cached!.name.local == 'dummy' ? null : cached;
    }

    _ensureIndexes();
    final key = _stripPrefix(name);
    final found = _groupsByName![key];
    if (found != null) {
      _groupDefsCache[name] = found;
      return found;
    }

    // Fallback linear search with a reasonable limit
    int searchCount = 0;
    const maxSearches = 1000;

    for (var group in _groupDefinitions!) {
      if (++searchCount > maxSearches) break;
      if (group.getAttribute('name') == key) {
        _groupDefsCache[name] = group;
        return group;
      }
    }

    _groupDefsCache[name] = XmlElement(XmlName('dummy'));
    return null;
  }

  XmlElement? _findTypeDef(String typeName) {
    if (_typeDefsCache.containsKey(typeName)) {
      final cached = _typeDefsCache[typeName];
      return cached!.name.local == 'dummy' ? null : cached;
    }

    _ensureIndexes();
    final key = _stripPrefix(typeName);
    final found = _typesByName![key];
    if (found != null) {
      _typeDefsCache[typeName] = found;
      return found;
    }

    _complexTypeDefinitions ??= [
      ...document.findAllElements('xs:complexType'),
      ...document.findAllElements('xsd:complexType')
    ];

    // Fallback linear search with a reasonable limit
    int searchCount = 0;
    const maxSearches = 500; // Smaller limit for type definitions

    for (var complexType in _complexTypeDefinitions!) {
      if (++searchCount > maxSearches) break;
      if (complexType.getAttribute('name') == key) {
        _typeDefsCache[typeName] = complexType;
        return complexType;
      }
    }

    _typeDefsCache[typeName] = XmlElement(XmlName('dummy'));
    return null;
  }

  void _extractChildElementsWithTimeoutAndVisited(XmlElement parentElementDef,
      List<String> validChildElements, Set<String> visited) {
    final elementName = parentElementDef.getAttribute('name');
    if (elementName != null && visited.contains(elementName)) {
      return; // Prevent infinite recursion
    }

    if (elementName != null) {
      visited.add(elementName);
    }

    // Handle direct element with complexType
    final complexType =
        parentElementDef.findElements('xs:complexType').firstOrNull ??
            parentElementDef.findElements('xsd:complexType').firstOrNull;

    if (complexType != null) {
      _extractChildElementsFromComplexTypeWithVisited(
          complexType, validChildElements, visited);
    } else {
      // Handle type reference with limited depth
      final typeAttr = parentElementDef.getAttribute('type');
      if (typeAttr != null) {
        final typeName = _stripPrefix(typeAttr);

        if (!visited.contains(typeName)) {
          final typeDefinition = _findTypeDef(typeName);
          if (typeDefinition != null) {
            visited.add(typeName);
            _extractChildElementsFromComplexTypeWithVisited(
                typeDefinition, validChildElements, visited);
          } else {
            // Try to find as a group if not found as complexType
            final groupDef = _findGroupDef(typeName);
            if (groupDef != null && !visited.contains(typeName)) {
              visited.add(typeName);
              _extractChildElementsFromSequenceWithVisited(
                  groupDef, validChildElements, visited,
                  maxDepth: 2);
            }
          }
        }
      }
    }

    // Handle group elements with limited depth
    final sequence = parentElementDef.findElements('xs:sequence').firstOrNull ??
        parentElementDef.findElements('xsd:sequence').firstOrNull;
    if (sequence != null) {
      _extractChildElementsFromSequenceWithVisited(
          sequence, validChildElements, visited,
          maxDepth: 2);
    }

    // Handle choice elements with limited depth
    final choice = parentElementDef.findElements('xs:choice').firstOrNull ??
        parentElementDef.findElements('xsd:choice').firstOrNull;
    if (choice != null) {
      _extractChildElementsFromChoiceWithVisited(
          choice, validChildElements, visited,
          maxDepth: 2);
    }

    // Handle xs:all similarly to sequence
    final allEl = parentElementDef.findElements('xs:all').firstOrNull ??
        parentElementDef.findElements('xsd:all').firstOrNull;
    if (allEl != null) {
      _extractChildElementsFromAllWithVisited(
          allEl, validChildElements, visited,
          maxDepth: 2);
    }
  }

  void _extractChildElementsFromComplexTypeWithVisited(XmlElement complexType,
      List<String> validChildElements, Set<String> visited,
      {int maxDepth = 3}) {
    if (maxDepth <= 0) return;

    // Handle complexContent (extension/restriction)
    final complexContent =
        complexType.findElements('xs:complexContent').firstOrNull ??
            complexType.findElements('xsd:complexContent').firstOrNull;
    if (complexContent != null) {
      // extension
      final extension =
          complexContent.findElements('xs:extension').firstOrNull ??
              complexContent.findElements('xsd:extension').firstOrNull;
      if (extension != null) {
        final base = extension.getAttribute('base');
        if (base != null) {
          final baseName = _stripPrefix(base);
          final baseType = _findTypeDef(baseName);
          if (baseType != null) {
            _extractChildElementsFromComplexTypeWithVisited(
                baseType, validChildElements, visited,
                maxDepth: maxDepth - 1);
          }
        }
        // Also process any sequences/choices under extension
        for (var seq in [
          ...extension.findElements('xs:sequence'),
          ...extension.findElements('xsd:sequence')
        ]) {
          _extractChildElementsFromSequenceWithVisited(
              seq, validChildElements, visited,
              maxDepth: maxDepth - 1);
        }
        for (var ch in [
          ...extension.findElements('xs:choice'),
          ...extension.findElements('xsd:choice')
        ]) {
          _extractChildElementsFromChoiceWithVisited(
              ch, validChildElements, visited,
              maxDepth: maxDepth - 1);
        }
      }

      // restriction (treat like base type's particles)
      final restriction =
          complexContent.findElements('xs:restriction').firstOrNull ??
              complexContent.findElements('xsd:restriction').firstOrNull;
      if (restriction != null) {
        final base = restriction.getAttribute('base');
        if (base != null) {
          final baseName = _stripPrefix(base);
          final baseType = _findTypeDef(baseName);
          if (baseType != null) {
            _extractChildElementsFromComplexTypeWithVisited(
                baseType, validChildElements, visited,
                maxDepth: maxDepth - 1);
          }
        }
        for (var seq in [
          ...restriction.findElements('xs:sequence'),
          ...restriction.findElements('xsd:sequence')
        ]) {
          _extractChildElementsFromSequenceWithVisited(
              seq, validChildElements, visited,
              maxDepth: maxDepth - 1);
        }
        for (var ch in [
          ...restriction.findElements('xs:choice'),
          ...restriction.findElements('xsd:choice')
        ]) {
          _extractChildElementsFromChoiceWithVisited(
              ch, validChildElements, visited,
              maxDepth: maxDepth - 1);
        }
      }
    }

    // Handle sequences within complex type
    final sequences = [
      ...complexType.findElements('xs:sequence'),
      ...complexType.findElements('xsd:sequence')
    ];
    for (var sequence in sequences) {
      _extractChildElementsFromSequenceWithVisited(
          sequence, validChildElements, visited,
          maxDepth: maxDepth - 1);
    }

    // Handle choices within complex type
    final choices = [
      ...complexType.findElements('xs:choice'),
      ...complexType.findElements('xsd:choice')
    ];
    for (var choice in choices) {
      _extractChildElementsFromChoiceWithVisited(
          choice, validChildElements, visited,
          maxDepth: maxDepth - 1);
    }

    // Handle xs:all within complex type
    final alls = [
      ...complexType.findElements('xs:all'),
      ...complexType.findElements('xsd:all')
    ];
    for (var all in alls) {
      _extractChildElementsFromAllWithVisited(all, validChildElements, visited,
          maxDepth: maxDepth - 1);
    }
  }

  void _extractChildElementsFromSequenceWithVisited(
      XmlElement sequence, List<String> validChildElements, Set<String> visited,
      {int maxDepth = 3}) {
    if (maxDepth <= 0) return;

    // Handle direct child elements (limit to avoid performance issues)
    final childElements = [
      ...sequence.findElements('xs:element'),
      ...sequence.findElements('xsd:element')
    ];

    int elementCount = 0;
    const maxElements = 50; // Limit to avoid processing too many elements

    for (var childElement in childElements) {
      if (++elementCount > maxElements) break;

      final childElementName = childElement.getAttribute('name');
      final ref = childElement.getAttribute('ref');
      if (childElementName != null) {
        validChildElements.add(childElementName);
      } else if (ref != null) {
        final refName = _stripPrefix(ref);
        // Resolve global element referenced by ref
        final def = _findElementDef(refName);
        if (def != null) {
          final defName = def.getAttribute('name');
          if (defName != null) {
            validChildElements.add(defName);
          }
        }
      }
    }

    // Handle group references (limit recursive depth)
    final groupRefs = [
      ...sequence.findElements('xs:group'),
      ...sequence.findElements('xsd:group')
    ];

    int groupCount = 0;
    const maxGroups = 10; // Limit group references to avoid infinite recursion

    for (var groupRef in groupRefs) {
      if (++groupCount > maxGroups) break;

      final refNameAttr = groupRef.getAttribute('ref');
      if (refNameAttr != null) {
        // Remove namespace prefix if present
        final groupName = _stripPrefix(refNameAttr);

        // Avoid infinite recursion by checking visited set
        if (!visited.contains(groupName) && maxDepth > 1) {
          visited.add(groupName);

          // Use direct group lookup instead of recursive getValidChildElements
          final groupDef = _findGroupDef(groupName);
          if (groupDef != null) {
            _extractChildElementsFromSequenceWithVisited(
                groupDef, validChildElements, visited,
                maxDepth: maxDepth - 1);
          }
        }
      }
    }
  }

  void _extractChildElementsFromChoiceWithVisited(
      XmlElement choice, List<String> validChildElements, Set<String> visited,
      {int maxDepth = 3}) {
    if (maxDepth <= 0) return;

    // Handle direct child elements in choice (limit to avoid performance issues)
    final childElements = [
      ...choice.findElements('xs:element'),
      ...choice.findElements('xsd:element')
    ];

    int elementCount = 0;
    const maxElements = 20; // Smaller limit for choice elements

    for (var childElement in childElements) {
      if (++elementCount > maxElements) break;

      final childElementName = childElement.getAttribute('name');
      final ref = childElement.getAttribute('ref');
      if (childElementName != null) {
        validChildElements.add(childElementName);
      } else if (ref != null) {
        final refName = _stripPrefix(ref);
        final def = _findElementDef(refName);
        if (def != null) {
          final defName = def.getAttribute('name');
          if (defName != null) validChildElements.add(defName);
        }
      }
    }
  }

  void _extractChildElementsFromAllWithVisited(
      XmlElement allEl, List<String> validChildElements, Set<String> visited,
      {int maxDepth = 3}) {
    if (maxDepth <= 0) return;
    final childElements = [
      ...allEl.findElements('xs:element'),
      ...allEl.findElements('xsd:element')
    ];
    for (var child in childElements) {
      final name = child.getAttribute('name');
      final ref = child.getAttribute('ref');
      if (name != null) {
        validChildElements.add(name);
      } else if (ref != null) {
        final def = _findElementDef(_stripPrefix(ref));
        final defName = def?.getAttribute('name');
        if (defName != null) validChildElements.add(defName);
      }
    }
  }

  List<String> getValidAttributes(String elementName) {
    final List<String> validAttributes = [];
    _ensureIndexes();

    final elementDef = _findElementDef(elementName);
    if (elementDef == null) return validAttributes;

    // Accumulate attributes from inline complexType, referenced type and complexContent base types
    void collectFromComplexType(
        XmlElement complexType, Set<String> visitedTypes,
        {int depth = 3}) {
      if (depth <= 0) return;

      // Direct attributes
      for (final attr in [
        ...complexType.findElements('xs:attribute'),
        ...complexType.findElements('xsd:attribute')
      ]) {
        final name = attr.getAttribute('name');
        if (name != null) validAttributes.add(name);
      }

      // Attribute groups not handled (can be added later)

      // complexContent
      final complexContent =
          complexType.findElements('xs:complexContent').firstOrNull ??
              complexType.findElements('xsd:complexContent').firstOrNull;
      if (complexContent != null) {
        final ext = complexContent.findElements('xs:extension').firstOrNull ??
            complexContent.findElements('xsd:extension').firstOrNull;
        if (ext != null) {
          // attributes inside extension
          for (final attr in [
            ...ext.findElements('xs:attribute'),
            ...ext.findElements('xsd:attribute')
          ]) {
            final name = attr.getAttribute('name');
            if (name != null) validAttributes.add(name);
          }
          final base = ext.getAttribute('base');
          if (base != null) {
            final baseName = _stripPrefix(base);
            if (!visitedTypes.contains(baseName)) {
              visitedTypes.add(baseName);
              final baseType = _findTypeDef(baseName);
              if (baseType != null) {
                collectFromComplexType(baseType, visitedTypes,
                    depth: depth - 1);
              }
            }
          }
        }

        final restr =
            complexContent.findElements('xs:restriction').firstOrNull ??
                complexContent.findElements('xsd:restriction').firstOrNull;
        if (restr != null) {
          for (final attr in [
            ...restr.findElements('xs:attribute'),
            ...restr.findElements('xsd:attribute')
          ]) {
            final name = attr.getAttribute('name');
            if (name != null) validAttributes.add(name);
          }
          final base = restr.getAttribute('base');
          if (base != null) {
            final baseName = _stripPrefix(base);
            if (!visitedTypes.contains(baseName)) {
              visitedTypes.add(baseName);
              final baseType = _findTypeDef(baseName);
              if (baseType != null) {
                collectFromComplexType(baseType, visitedTypes,
                    depth: depth - 1);
              }
            }
          }
        }
      }
    }

    // Inline complexType
    final inlineType = elementDef.findElements('xs:complexType').firstOrNull ??
        elementDef.findElements('xsd:complexType').firstOrNull;
    if (inlineType != null) {
      collectFromComplexType(inlineType, <String>{});
    }

    // Referenced type
    final typeAttr = elementDef.getAttribute('type');
    if (typeAttr != null) {
      final typeName = _stripPrefix(typeAttr);
      final typeDef = _findTypeDef(typeName);
      if (typeDef != null) {
        collectFromComplexType(typeDef, <String>{});
      }
    }

    return validAttributes.toSet().toList();
  }
}
