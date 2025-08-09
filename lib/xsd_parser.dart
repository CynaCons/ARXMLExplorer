import 'package:xml/xml.dart';

class XsdParser {
  final XmlDocument document;
  final bool verbose;
  final int particleDepthLimit;
  final int groupDepthLimit;

  // Cache to avoid repeated expensive lookups
  final Map<String, List<String>> _childElementsCache = {};
  final Map<String, XmlElement> _elementDefsCache = {};
  final Map<String, XmlElement> _groupDefsCache = {};
  final Map<String, XmlElement> _typeDefsCache = {};

  // Indexes for fast lookup by @name (namespace-agnostic)
  Map<String, XmlElement>? _elementsByName;
  Map<String, XmlElement>? _groupsByName;
  Map<String, XmlElement>? _typesByName;
  Map<String, List<String>>? _subsByHeadName;

  // Lazy-loaded collections
  List<XmlElement>? _elementDefinitions;
  List<XmlElement>? _groupDefinitions;
  List<XmlElement>? _complexTypeDefinitions;

  XsdParser(String xsdContent,
      {this.verbose = false,
      this.particleDepthLimit = 3,
      this.groupDepthLimit = 2})
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
        _v('Extracting children for "$parentElementName"');
        _extractChildElementsWithTimeoutAndVisited(
            parentElementDef, validChildElements, visited);
        _v('Collected ${validChildElements.toSet().length} candidates for "$parentElementName"');
      } catch (e) {
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
    if (_subsByHeadName == null) {
      _subsByHeadName = {};
      for (final el in [
        ...document.findAllElements('xs:element'),
        ...document.findAllElements('xsd:element')
      ]) {
        final sub = el.getAttribute('substitutionGroup');
        final name = el.getAttribute('name');
        if (sub != null && name != null) {
          final head = _stripPrefix(sub);
          final list = _subsByHeadName!.putIfAbsent(head, () => <String>[]);
          list.add(name);
        }
      }
    }
  }

  String _stripPrefix(String name) =>
      name.contains(':') ? name.split(':').last : name;

  void _addNameWithSubstitutions(List<String> target, String name) {
    target.add(name);
    final subs = _subsByHeadName?[name];
    if (subs != null && subs.isNotEmpty) {
      target.addAll(subs);
    }
  }

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

  // New helper: extract children from a group definition by descending into its particles
  void _extractFromGroupDef(
      XmlElement groupDef, List<String> validChildElements, Set<String> visited,
      {int maxDepth = 2}) {
    if (maxDepth < 0) return;

    // sequences
    for (final sequence in [
      ...groupDef.findElements('xs:sequence'),
      ...groupDef.findElements('xsd:sequence')
    ]) {
      _v(' Descend group -> sequence (${groupDef.getAttribute('name') ?? 'anon'})');
      _extractChildElementsFromSequenceWithVisited(
          sequence, validChildElements, visited,
          maxDepth: maxDepth);
    }

    // choices
    for (final choice in [
      ...groupDef.findElements('xs:choice'),
      ...groupDef.findElements('xsd:choice')
    ]) {
      _v(' Descend group -> choice (${groupDef.getAttribute('name') ?? 'anon'})');
      _extractChildElementsFromChoiceWithVisited(
          choice, validChildElements, visited,
          maxDepth: maxDepth);
    }

    // all
    for (final allEl in [
      ...groupDef.findElements('xs:all'),
      ...groupDef.findElements('xsd:all')
    ]) {
      _v(' Descend group -> all (${groupDef.getAttribute('name') ?? 'anon'})');
      _extractChildElementsFromAllWithVisited(
          allEl, validChildElements, visited,
          maxDepth: maxDepth);
    }
  }

  void _extractChildElementsWithTimeoutAndVisited(XmlElement parentElementDef,
      List<String> validChildElements, Set<String> visited) {
    final elementName = parentElementDef.getAttribute('name');
    if (elementName != null && visited.contains(_vk('el', elementName))) {
      return; // Prevent infinite recursion
    }

    if (elementName != null) {
      visited.add(_vk('el', elementName));
    }

    final complexType =
        parentElementDef.findElements('xs:complexType').firstOrNull ??
            parentElementDef.findElements('xsd:complexType').firstOrNull;

    if (complexType != null) {
      _v('  Found inline complexType for ${elementName ?? '(anonymous)'}');
      _extractChildElementsFromComplexTypeWithVisited(
          complexType, validChildElements, visited);
    } else {
      final typeAttr = parentElementDef.getAttribute('type');
      if (typeAttr != null) {
        final typeName = _stripPrefix(typeAttr);
        final typeKey = _vk('type', typeName);
        if (!visited.contains(typeKey)) {
          final typeDefinition = _findTypeDef(typeName);
          if (typeDefinition != null) {
            _v('  Resolving type $typeName for ${elementName ?? '(anonymous)'}');
            visited.add(typeKey);
            _extractChildElementsFromComplexTypeWithVisited(
                typeDefinition, validChildElements, visited);
          } else {
            final groupDef = _findGroupDef(typeName);
            if (groupDef != null && !visited.contains(typeKey)) {
              _v('  Resolving group $typeName for ${elementName ?? '(anonymous)'}');
              visited.add(typeKey);
              _extractFromGroupDef(groupDef, validChildElements, visited,
                  maxDepth: groupDepthLimit);
            }
          }
        }
      }
    }

    final sequence = parentElementDef.findElements('xs:sequence').firstOrNull ??
        parentElementDef.findElements('xsd:sequence').firstOrNull;
    if (sequence != null) {
      _v('  Descend element -> sequence (${elementName ?? 'anon'})');
      _extractChildElementsFromSequenceWithVisited(
          sequence, validChildElements, visited,
          maxDepth: groupDepthLimit);
    }

    final choice = parentElementDef.findElements('xs:choice').firstOrNull ??
        parentElementDef.findElements('xsd:choice').firstOrNull;
    if (choice != null) {
      _v('  Descend element -> choice (${elementName ?? 'anon'})');
      _extractChildElementsFromChoiceWithVisited(
          choice, validChildElements, visited,
          maxDepth: groupDepthLimit);
    }

    final allEl = parentElementDef.findElements('xs:all').firstOrNull ??
        parentElementDef.findElements('xsd:all').firstOrNull;
    if (allEl != null) {
      _v('  Descend element -> all (${elementName ?? 'anon'})');
      _extractChildElementsFromAllWithVisited(
          allEl, validChildElements, visited,
          maxDepth: groupDepthLimit);
    }
  }

  void _extractChildElementsFromComplexTypeWithVisited(XmlElement complexType,
      List<String> validChildElements, Set<String> visited,
      {int maxDepth = 3}) {
    if (maxDepth <= 0) return;

    final complexContent =
        complexType.findElements('xs:complexContent').firstOrNull ??
            complexType.findElements('xsd:complexContent').firstOrNull;
    if (complexContent != null) {
      final extension =
          complexContent.findElements('xs:extension').firstOrNull ??
              complexContent.findElements('xsd:extension').firstOrNull;
      if (extension != null) {
        final base = extension.getAttribute('base');
        if (base != null) {
          final baseName = _stripPrefix(base);
          final baseType = _findTypeDef(baseName);
          if (baseType != null) {
            _v('   complexContent extension -> base $baseName');
            _extractChildElementsFromComplexTypeWithVisited(
                baseType, validChildElements, visited,
                maxDepth: maxDepth - 1);
          }
        }
        for (var seq in [
          ...extension.findElements('xs:sequence'),
          ...extension.findElements('xsd:sequence')
        ]) {
          _v('   complexContent extension -> sequence');
          _extractChildElementsFromSequenceWithVisited(
              seq, validChildElements, visited,
              maxDepth: maxDepth - 1);
        }
        for (var ch in [
          ...extension.findElements('xs:choice'),
          ...extension.findElements('xsd:choice')
        ]) {
          _v('   complexContent extension -> choice');
          _extractChildElementsFromChoiceWithVisited(
              ch, validChildElements, visited,
              maxDepth: maxDepth - 1);
        }
      }

      final restriction =
          complexContent.findElements('xs:restriction').firstOrNull ??
              complexContent.findElements('xsd:restriction').firstOrNull;
      if (restriction != null) {
        final base = restriction.getAttribute('base');
        if (base != null) {
          final baseName = _stripPrefix(base);
          final baseType = _findTypeDef(baseName);
          if (baseType != null) {
            _v('   complexContent restriction -> base $baseName');
            _extractChildElementsFromComplexTypeWithVisited(
                baseType, validChildElements, visited,
                maxDepth: maxDepth - 1);
          }
        }
        for (var seq in [
          ...restriction.findElements('xs:sequence'),
          ...restriction.findElements('xsd:sequence')
        ]) {
          _v('   complexContent restriction -> sequence');
          _extractChildElementsFromSequenceWithVisited(
              seq, validChildElements, visited,
              maxDepth: maxDepth - 1);
        }
        for (var ch in [
          ...restriction.findElements('xs:choice'),
          ...restriction.findElements('xsd:choice')
        ]) {
          _v('   complexContent restriction -> choice');
          _extractChildElementsFromChoiceWithVisited(
              ch, validChildElements, visited,
              maxDepth: maxDepth - 1);
        }
      }
    }

    for (var sequence in [
      ...complexType.findElements('xs:sequence'),
      ...complexType.findElements('xsd:sequence')
    ]) {
      _v('   complexType -> sequence');
      _extractChildElementsFromSequenceWithVisited(
          sequence, validChildElements, visited,
          maxDepth: (maxDepth - 1).clamp(0, particleDepthLimit));
    }

    for (var choice in [
      ...complexType.findElements('xs:choice'),
      ...complexType.findElements('xsd:choice')
    ]) {
      _v('   complexType -> choice');
      _extractChildElementsFromChoiceWithVisited(
          choice, validChildElements, visited,
          maxDepth: (maxDepth - 1).clamp(0, particleDepthLimit));
    }

    for (var all in [
      ...complexType.findElements('xs:all'),
      ...complexType.findElements('xsd:all')
    ]) {
      _v('   complexType -> all');
      _extractChildElementsFromAllWithVisited(all, validChildElements, visited,
          maxDepth: (maxDepth - 1).clamp(0, particleDepthLimit));
    }
  }

  void _extractChildElementsFromSequenceWithVisited(
      XmlElement sequence, List<String> validChildElements, Set<String> visited,
      {int maxDepth = 3}) {
    // Always collect direct element children; use maxDepth only to limit recursion
    final allowRecurse = maxDepth > 0;

    final childElements = [
      ...sequence.findElements('xs:element'),
      ...sequence.findElements('xsd:element')
    ];

    int elementCount = 0;
    const maxElements = 2000; // AUTOSAR schemas have very large sequences

    for (var childElement in childElements) {
      if (++elementCount > maxElements) break;

      final childElementName = childElement.getAttribute('name');
      final ref = childElement.getAttribute('ref');
      if (childElementName != null) {
        _v('    + element $childElementName');
        _addNameWithSubstitutions(validChildElements, childElementName);
      } else if (ref != null) {
        final refName = _stripPrefix(ref);
        final def = _findElementDef(refName);
        if (def != null) {
          final defName = def.getAttribute('name');
          if (defName != null) {
            _v('    + element(ref) $defName');
            _addNameWithSubstitutions(validChildElements, defName);
          }
        }
      }
    }

    // Handle group references inside a sequence
    final groupRefs = [
      ...sequence.findElements('xs:group'),
      ...sequence.findElements('xsd:group')
    ];

    int groupCount = 0;
    const maxGroups = 50;

    for (var groupRef in groupRefs) {
      if (++groupCount > maxGroups) break;

      final refNameAttr = groupRef.getAttribute('ref');
      if (refNameAttr != null) {
        final groupName = _stripPrefix(refNameAttr);
        final groupKey = _vk('group', groupName);
        if (!visited.contains(groupKey) && allowRecurse) {
          visited.add(groupKey);
          final groupDef = _findGroupDef(groupName);
          if (groupDef != null) {
            _v('    -> group $groupName');
            _extractFromGroupDef(groupDef, validChildElements, visited,
                maxDepth: maxDepth - 1);
          }
        }
      }
    }

    // Handle nested compositor particles inside sequence
    if (allowRecurse) {
      for (final nestedSeq in [
        ...sequence.findElements('xs:sequence'),
        ...sequence.findElements('xsd:sequence')
      ]) {
        _v('    -> nested sequence');
        _extractChildElementsFromSequenceWithVisited(
            nestedSeq, validChildElements, visited,
            maxDepth: maxDepth - 1);
      }
      for (final nestedChoice in [
        ...sequence.findElements('xs:choice'),
        ...sequence.findElements('xsd:choice')
      ]) {
        _v('    -> nested choice');
        _extractChildElementsFromChoiceWithVisited(
            nestedChoice, validChildElements, visited,
            maxDepth: maxDepth - 1);
      }
      for (final nestedAll in [
        ...sequence.findElements('xs:all'),
        ...sequence.findElements('xsd:all')
      ]) {
        _v('    -> nested all');
        _extractChildElementsFromAllWithVisited(
            nestedAll, validChildElements, visited,
            maxDepth: maxDepth - 1);
      }
    }
  }

  void _extractChildElementsFromChoiceWithVisited(
      XmlElement choice, List<String> validChildElements, Set<String> visited,
      {int maxDepth = 3}) {
    // Always collect direct element children; use maxDepth only to limit recursion
    final allowRecurse = maxDepth > 0;

    final childElements = [
      ...choice.findElements('xs:element'),
      ...choice.findElements('xsd:element')
    ];

    int elementCount = 0;
    const maxElements = 5000; // AUTOSAR ELEMENTS choices can list thousands

    for (var childElement in childElements) {
      if (++elementCount > maxElements) break;

      final childElementName = childElement.getAttribute('name');
      final ref = childElement.getAttribute('ref');
      if (childElementName != null) {
        _v('    + element $childElementName');
        _addNameWithSubstitutions(validChildElements, childElementName);
      } else if (ref != null) {
        final refName = _stripPrefix(ref);
        final def = _findElementDef(refName);
        if (def != null) {
          final defName = def.getAttribute('name');
          if (defName != null) {
            _v('    + element(ref) $defName');
            _addNameWithSubstitutions(validChildElements, defName);
          }
        }
      }
    }

    // Handle group references inside a choice
    final groupRefs = [
      ...choice.findElements('xs:group'),
      ...choice.findElements('xsd:group')
    ];
    for (final groupRef in groupRefs) {
      final refNameAttr = groupRef.getAttribute('ref');
      if (refNameAttr != null && allowRecurse) {
        final groupName = _stripPrefix(refNameAttr);
        final groupKey = _vk('group', groupName);
        if (!visited.contains(groupKey)) {
          visited.add(groupKey);
          final groupDef = _findGroupDef(groupName);
          if (groupDef != null) {
            _v('    -> group $groupName');
            _extractFromGroupDef(groupDef, validChildElements, visited,
                maxDepth: maxDepth - 1);
          }
        }
      }
    }

    // Handle nested compositor particles inside choice
    if (allowRecurse) {
      for (final nestedSeq in [
        ...choice.findElements('xs:sequence'),
        ...choice.findElements('xsd:sequence')
      ]) {
        _v('    -> nested sequence');
        _extractChildElementsFromSequenceWithVisited(
            nestedSeq, validChildElements, visited,
            maxDepth: maxDepth - 1);
      }
      for (final nestedChoice in [
        ...choice.findElements('xs:choice'),
        ...choice.findElements('xsd:choice')
      ]) {
        _v('    -> nested choice');
        _extractChildElementsFromChoiceWithVisited(
            nestedChoice, validChildElements, visited,
            maxDepth: maxDepth - 1);
      }
      for (final nestedAll in [
        ...choice.findElements('xs:all'),
        ...choice.findElements('xsd:all')
      ]) {
        _v('    -> nested all');
        _extractChildElementsFromAllWithVisited(
            nestedAll, validChildElements, visited,
            maxDepth: maxDepth - 1);
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
        _v('    + element $name');
        _addNameWithSubstitutions(validChildElements, name);
      } else if (ref != null) {
        final def = _findElementDef(_stripPrefix(ref));
        final defName = def?.getAttribute('name');
        if (defName != null) {
          _v('    + element(ref) $defName');
          _addNameWithSubstitutions(validChildElements, defName);
        }
      }
    }

    // Nested particles in all (rare but safe to handle)
    for (final nestedSeq in [
      ...allEl.findElements('xs:sequence'),
      ...allEl.findElements('xsd:sequence')
    ]) {
      _v('    -> nested sequence');
      _extractChildElementsFromSequenceWithVisited(
          nestedSeq, validChildElements, visited,
          maxDepth: maxDepth - 1);
    }
    for (final nestedChoice in [
      ...allEl.findElements('xs:choice'),
      ...allEl.findElements('xsd:choice')
    ]) {
      _v('    -> nested choice');
      _extractChildElementsFromChoiceWithVisited(
          nestedChoice, validChildElements, visited,
          maxDepth: maxDepth - 1);
    }
  }

  List<String> getValidAttributes(String elementName) {
    final List<String> validAttributes = [];
    _ensureIndexes();

    final elementDef = _findElementDef(elementName);
    if (elementDef == null) return validAttributes;

    void collectFromComplexType(
        XmlElement complexType, Set<String> visitedTypes,
        {int depth = 3}) {
      if (depth <= 0) return;

      for (final attr in [
        ...complexType.findElements('xs:attribute'),
        ...complexType.findElements('xsd:attribute')
      ]) {
        final name = attr.getAttribute('name');
        if (name != null) validAttributes.add(name);
      }

      final complexContent =
          complexType.findElements('xs:complexContent').firstOrNull ??
              complexType.findElements('xsd:complexContent').firstOrNull;
      if (complexContent != null) {
        final ext = complexContent.findElements('xs:extension').firstOrNull ??
            complexContent.findElements('xsd:extension').firstOrNull;
        if (ext != null) {
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

    final inlineType = elementDef.findElements('xs:complexType').firstOrNull ??
        elementDef.findElements('xsd:complexType').firstOrNull;
    if (inlineType != null) {
      collectFromComplexType(inlineType, <String>{}, depth: particleDepthLimit);
    }

    final typeAttr = elementDef.getAttribute('type');
    if (typeAttr != null) {
      final typeName = _stripPrefix(typeAttr);
      final typeDef = _findTypeDef(typeName);
      if (typeDef != null) {
        collectFromComplexType(typeDef, <String>{}, depth: particleDepthLimit);
      }
    }

    return validAttributes.toSet().toList();
  }

  // Build a namespaced key for visited tracking
  String _vk(String kind, String name) => '$kind:$name';

  // Verbose logging helper
  void _v(String message) {
    if (verbose) print('XSD: $message');
  }
}
