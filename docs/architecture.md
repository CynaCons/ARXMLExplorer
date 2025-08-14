# ARXMLExplorer Architecture

```
+----------------------+  Presentation Layer (Flutter Widgets, Views)
| ui/, features/*/view |  Depends on application + core barrels
+-----------+----------+
            |
            v
+----------------------+  Application Layer (State, Providers, Commands, Services)
| features/*/state     |  Depends on core only
+-----------+----------+
            |
            v
+----------------------+  Core Layer (Pure Models, Parsers, Validation, Refs)
| core/*, xsd_parser   |  No upward deps
+----------------------+
```

## Current Project Structure

```
lib/
├── main.dart                     # App entry point
├── app_providers.dart            # Global provider configuration
├── core/                         # Core layer (pure logic)
│   ├── core.dart                # Core barrel export
│   ├── models/                  # Data models (ElementNode, etc.)
│   ├── validation/              # Validation logic and issues
│   ├── refs/                    # Reference normalization
│   ├── cache/                   # AST caching (ast_cache.dart)
│   ├── loaders/                 # File loaders (arxmlloader.dart)
│   └── xsd/                     # XSD parsing logic
├── features/                     # Feature modules
│   ├── editor/                  # Editor feature
│   │   ├── editor.dart          # Editor barrel export
│   │   ├── state/               # Editor state (arxml_tree_view_state.dart, file_tabs_provider.dart)
│   │   │   └── commands/        # Edit commands
│   │   └── view/                # Editor UI widgets
│   │       └── widgets/         # Element node widgets, search, etc.
│   ├── workspace/               # Workspace feature
│   │   ├── workspace.dart       # Workspace barrel export
│   │   ├── state/               # Workspace state (workspace_indexer.dart)
│   │   ├── service/             # Workspace services
│   │   └── view/                # Workspace UI
│   └── validation/              # Validation feature
│       ├── validation.dart      # Validation barrel export
│       ├── state/               # Validation providers
│       └── view/                # Validation UI
├── ui/                          # Shared UI components
└── res/                         # Resources
```

## Migration Status
- ✅ All legacy files migrated to proper modular locations
- ✅ Backward-compatible shims created for smooth transition
- ✅ Barrel exports implemented for clean imports
- ✅ Tests updated to use new import structure
- ✅ 60+ tests passing with new architecture

Key Barrels:
- core/core.dart: ElementNode, validation primitives, reference normalization, AST cache, ARXML loader
- features/editor/editor.dart: editor view, file tabs provider, command API, tree view state
- features/workspace/workspace.dart: workspace view, models, and indexing
- features/validation/validation.dart: validation view + provider + issues

Legacy Shims (Backward Compatibility):
- All legacy files (elementnode.dart, arxml_validator.dart, depth_indicator.dart, ref_normalizer.dart, arxmlloader.dart, workspace_indexer.dart, arxml_tree_view_state.dart, etc.) now re-export from their proper modular locations
- Shims maintain backward compatibility during transition period
- Remove shims in future breaking change once all external references updated

Commands:
EditValueCommand, RenameTagCommand, AddChildCommand, DeleteNodeCommand, ConvertTypeCommand, SafeRenameShortNameCommand implement ArxmlEditCommand.
Structural commands override isStructural() to trigger tree flat map rebuilds.

Validation:
ArxmlValidator (core/validation) performs XSD-based child validation returning ValidationIssue instances with severities.

Reference Normalization:
RefNormalizer (core/refs) plus domain variants for ECUC and Port references unify reference keys for workspace indexing and go-to-definition.

## Import Guidelines

### Recommended Import Patterns:
```dart
// ✅ Use barrel imports for cross-feature dependencies
import 'package:arxml_explorer/core/core.dart';
import 'package:arxml_explorer/features/editor/editor.dart';
import 'package:arxml_explorer/features/workspace/workspace.dart';

// ✅ Use relative imports within same feature
import '../state/file_tabs_provider.dart';
import '../../editor.dart';

// ❌ Avoid direct imports from other features
import 'package:arxml_explorer/features/editor/state/arxml_tree_view_state.dart';
```

### Dependency Rules:
- Presentation layer → Application layer → Core layer (no reverse dependencies)
- Features can depend on core but not on other features directly
- Cross-feature communication through shared state in app_providers.dart
- Legacy shim imports work but are deprecated
