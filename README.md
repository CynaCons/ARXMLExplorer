# ARXMLExplorer
An AUTOSAR XML explorer and editor built with Flutter.

## Project Status: Active Development

Latest: Architecture refactoring in progress with core package extraction and comprehensive testing improvements.

### Key Features
- ARXML File Viewer: Interactive tree view with navigation rail
- Multi-File Workspace: Workspace management with cross-file reference resolution
- Live Validation: Real-time XSD validation with contextual error reporting
- Advanced Editing: Schema-compliant editing with undo/redo command system
- Search & Navigation: Find elements with auto-scroll and keyboard navigation
- Performance Optimized: Handles large ARXML files with AST caching and virtualization
- Modern UI: Material Design with tab management and responsive layout

### Development Status
- Architecture: Layered design with core package separation
- Core Features: File operations, editing, validation implemented
- Testing: Widget + unit suite; run `flutter test` for the current status
- Build: `flutter analyze` reports no errors or warnings (info-level lints remain)
- Performance: Optimized for large files with bounded timeouts

## Setup & Installation

Prerequisites
- Flutter SDK (>=3.0.0 <4.0.0)
- Dart SDK
- An IDE (VS Code, Android Studio, etc.)

Quick Start
```
# Clone the repository
git clone <repository-url>
cd ARXMLExplorer

# Get dependencies
flutter pub get

# Run analyzer
flutter analyze

# Run tests (see XSD provisioning below)
flutter test

# Run the application
flutter run
```

## Testing

Run all tests
```
flutter test
```

Common groups
```
flutter test test/core/                    # Core functionality tests
flutter test test/features/editor/         # Editor feature tests
flutter test test/integration/             # Integration tests
flutter test test/performance/             # Performance benchmarks
```

Test Structure
```
test/
  core/            # Core layer tests
    xsd/
    validation/
    refs/
  features/        # Feature module tests
    editor/
    workspace/
  integration/     # End-to-end integration tests
  performance/     # Performance and load tests
  app/             # Application-level tests
  support/         # Test utilities and mocks
  res/             # Test resources
    generic_ecu.arxml
    test.xsd
```

## Project Structure

```
lib/
  main.dart                    # Application entry point
  app_providers.dart           # Global Riverpod providers
  ui/                          # Shell UI components
    home_shell.dart            # Main navigation shell
  features/                    # Feature modules
    editor/
      view/
      state/
    workspace/
    validation/
    settings/
  core/                        # Pure Dart business logic (no Flutter imports)
    models/
    xml/
    xsd/
    validation/
    refs/
    cache/
    diagnostics/               # Log facade
    resources/                 # ResourceLocator (schema discovery)
```

`core/` is plain Dart: no `flutter`, no plugins, and no imports from
`features/` or `ui/`. CI enforces this — see `.github/workflows/ci.yml`.

### Legacy Shims
All legacy top-level shim files under `lib/` have been removed. Use the modular paths:
- core modules under `lib/core/...`
- editor modules under `lib/features/editor/...`
- workspace modules under `lib/features/workspace/...`

### Configuration Files
```
pubspec.yaml             # Dependencies and local packages
analysis_options.yaml    # Dart analyzer + dart_code_metrics
dart_test.yaml           # Global test timeout configuration
PLAN.md                  # Detailed development roadmap
PRD.md                   # Product requirements
docs/architecture.md     # Technical architecture guide
RULES.md                 # Dependency rules and coding standards
```

## Development Notes

### Architecture Highlights
- Layered Design: Presentation → Application → Core with strict dependency rules
- Command Pattern: Structured editing with undo/redo support
- Riverpod State: Reactive state management with provider composition
- Performance: AST caching, incremental indexing, timeout optimization

### Recent Major Improvements
- Modular Architecture: Feature-based organization with barrel exports
- Enhanced Validation: Context-aware XSD validation with value node filtering
- Test Stabilization: Timeout management and bounded pump patterns
- UI Modernization: Navigation rail, tab management, live validation toggles
- Save / Save All / Undo / Redo restored to the rail, with keyboard shortcuts
- Schema discovery via `ResourceLocator` so installed builds find their XSDs

### Current Development Focus (PLAN.md)
- UI Polish: Navigation rail redesign, AppBar consolidation
- Workspace Features: Hierarchical directory tree, cross-file indexing
- Test Migration: Moving tests to new feature-based structure
- Performance: Editor navigation improvements, smooth scrolling

## Documentation
- Development Plan: PLAN.md
- Product Requirements: PRD.md
- Architecture Guide: docs/architecture.md
- Coding Rules: RULES.md

## Contributing
1. Fork the repository
2. Create a feature branch following the modular architecture
3. Follow layer dependency rules (see docs/architecture.md and RULES.md)
4. Run tests: `flutter test`
5. Ensure analyzer compliance: `flutter analyze`
6. Submit a pull request

## License
See LICENSE file for details.

## Provisioning AUTOSAR XSDs
Large AUTOSAR XSD files are not committed to the repository. The app searches
these locations in order, first hit wins:

1. `ARXML_XSD_DIR` environment variable — explicit override
2. `<cwd>/lib/res/xsd` — source checkout
3. `<executable dir>/data/flutter_assets/lib/res/xsd` — Flutter asset bundle
4. `<executable dir>/res/xsd`, then `<executable dir>/../res/xsd`
5. Per-user data directory:
   - Windows: `%APPDATA%/ARXMLExplorer/xsd`
   - Linux: `$XDG_DATA_HOME/arxml_explorer/xsd`, else `~/.local/share/arxml_explorer/xsd`
   - macOS: `~/Library/Application Support/ARXMLExplorer/xsd`

For development, copy your licensed schemas into `lib/res/xsd/`. For an
installed build, use the per-user directory or set `ARXML_XSD_DIR`.

Helper:
- Run `dart run tool/verify_xsds.dart` to check presence and get guidance.

Tests that need real AUTOSAR schemas skip themselves with a message when the
schemas are absent, so `flutter test` is green on a bare checkout.

